#!/usr/bin/env python3
"""Synthetic generator for case_prod_compound_snapwave.

Builds a >100k cell quadtree mesh (3 refinement levels) over a synthetic
sloped-shelf bathymetry, builds matching subgrid tables, writes
SFINCS open-boundary tidal forcing (M2 + M4 + sea-level constant) on the
western edge, and writes SnapWave wave-spectrum forcing (storm-event Hs
ramp + Tp tracking + steady wave direction + steady spreading) at two
support points along the same western edge so the tide and wave
boundaries are simultaneously active throughout the run.

Requires hydromt-sfincs (and its deps) in the active Python environment.

Usage (from the repo root):

    /tmp/sfincs-hydromt-venv/bin/python3 \
        tests/cases/case_prod_compound_snapwave/generate.py \
        --out tests/cases/case_prod_compound_snapwave
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import xarray as xr
import xugrid as xu
from pyproj import CRS
from shapely.geometry import Polygon


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="output case directory")
    parser.add_argument("--nmax", type=int, default=130)
    parser.add_argument("--mmax", type=int, default=130)
    parser.add_argument("--dx", type=float, default=200.0)
    parser.add_argument("--epsg", type=int, default=32633)
    return parser.parse_args()


def synth_bathymetry(x: np.ndarray, y: np.ndarray, mmax_m: float) -> np.ndarray:
    """Linear west->east sea -> shore gradient, plus small ripples.

    West (small x) is offshore at -10 m, east (large x) is land at +5 m.
    Adds 20 cm pixel-scale ripples so the subgrid table has variation.
    """
    frac = np.clip(x / mmax_m, 0.0, 1.0)
    base = -10.0 + 15.0 * frac
    ripple = 0.20 * np.sin(2 * np.pi * x / 600.0) * np.cos(2 * np.pi * y / 600.0)
    return (base + ripple).astype(np.float32)


def build_synthetic_dem(x0, y0, dx_m, dy_m, mmax, nmax, refi):
    """Build a synthetic DEM raster covering the model domain at fine resolution."""
    pixel = min(dx_m, dy_m) / refi
    nx = int(np.ceil(mmax * dx_m / pixel))
    ny = int(np.ceil(nmax * dy_m / pixel))
    xs = x0 + (np.arange(nx) + 0.5) * pixel
    ys = y0 + (np.arange(ny) + 0.5) * pixel
    xx, yy = np.meshgrid(xs, ys)
    z = synth_bathymetry(xx, yy, mmax * dx_m)
    da = xr.DataArray(
        z,
        dims=("y", "x"),
        coords={"x": xs, "y": ys},
        name="elevtn",
    )
    da.raster.set_crs(CRS.from_epsg(32633))
    return da


def build_refinement_polygons(x0, y0, mmax_m, nmax_m, crs):
    """Two nested rectangular refinement polygons (concentric on grid centre)."""
    cx = x0 + mmax_m / 2.0
    cy = y0 + nmax_m / 2.0

    def rect(half_w, half_h):
        return Polygon([
            (cx - half_w, cy - half_h),
            (cx + half_w, cy - half_h),
            (cx + half_w, cy + half_h),
            (cx - half_w, cy + half_h),
        ])

    outer = rect(0.40 * mmax_m, 0.40 * nmax_m)
    inner = rect(0.25 * mmax_m, 0.25 * nmax_m)
    gdf = gpd.GeoDataFrame(
        {"refinement_level": [1, 2], "geometry": [outer, inner]},
        crs=crs,
    )
    return gdf


def storm_hs(t_s: np.ndarray) -> np.ndarray:
    """Storm-event significant wave height profile.

    Ramps Hs linearly from 1.0 m at t=0 up to 4.0 m at t=12 h, holds at
    4.0 m through t=18 h, then decays linearly back to 1.0 m by t=24 h.
    Smoothly piecewise-linear; non-trivial over the 24 h window so the
    SnapWave coupling sees a meaningful boundary signal.
    """
    h12 = 12 * 3600.0
    h18 = 18 * 3600.0
    h24 = 24 * 3600.0
    out = np.empty_like(t_s, dtype=np.float64)
    rise = t_s <= h12
    hold = (t_s > h12) & (t_s <= h18)
    fall = t_s > h18
    out[rise] = 1.0 + (4.0 - 1.0) * (t_s[rise] / h12)
    out[hold] = 4.0
    out[fall] = 4.0 - (4.0 - 1.0) * ((t_s[fall] - h18) / (h24 - h18))
    return out


def storm_tp(t_s: np.ndarray) -> np.ndarray:
    """Tp tracks Hs roughly: Tp = 6 s + 0.5 * (Hs / 1 m), clamped 6..12 s."""
    hs = storm_hs(t_s)
    tp = 6.0 + 1.5 * hs
    return np.clip(tp, 6.0, 12.0)


def main():
    args = parse_args()
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    repo_root = Path(__file__).resolve().parents[3]
    sys.path.insert(0, str((repo_root.parent / "hydromt_sfincs").resolve()))

    from hydromt_sfincs.components.quadtree.quadtree_builder import (  # noqa: E402
        build_quadtree_xugrid,
    )
    from hydromt_sfincs.components.quadtree.subgrid_quadtree_builder import (  # noqa: E402
        build_subgrid_table_quadtree,
    )

    crs = CRS.from_epsg(args.epsg)

    nmax = args.nmax
    mmax = args.mmax
    dx = args.dx
    dy = args.dx
    x0 = 0.0
    y0 = 0.0
    rotation = 0.0
    nr_subgrid_pixels = 20
    refi = nr_subgrid_pixels

    print(f"Building quadtree base grid {nmax} x {mmax} at {dx} m, 3 levels")
    refinement_polygons = build_refinement_polygons(
        x0, y0, mmax * dx, nmax * dy, crs
    )

    grid = build_quadtree_xugrid(
        x0=x0,
        y0=y0,
        nmax=nmax,
        mmax=mmax,
        dx=dx,
        dy=dy,
        rotation=rotation,
        crs=crs,
        refinement_polygons=refinement_polygons,
        elevation_list=None,
        bathymetry_database=None,
    )

    nr_cells = grid.sizes["mesh2d_nFaces"]
    nr_levels_in_grid = int(grid.attrs["nr_levels"])
    print(f"Built quadtree: {nr_cells} cells, {nr_levels_in_grid} levels")
    if nr_cells < 100_000:
        raise SystemExit(f"FATAL: only {nr_cells} cells < 100000 — increase nmax/mmax")
    if nr_levels_in_grid < 3:
        raise SystemExit(f"FATAL: only {nr_levels_in_grid} levels < 3")

    n_cell = grid["n"].values - 1
    m_cell = grid["m"].values - 1
    lev_cell = grid["level"].values - 1
    cell_dx = dx / (2 ** lev_cell)
    cell_dy = dy / (2 ** lev_cell)
    xc = x0 + (m_cell + 0.5) * cell_dx
    yc = y0 + (n_cell + 0.5) * cell_dy

    z_cell = synth_bathymetry(xc, yc, mmax * dx)
    grid["z"] = xu.UgridDataArray(
        xr.DataArray(z_cell.astype(np.float64), dims=[grid.grid.face_dimension]),
        grid.grid,
    )

    # Mask: 2 (open boundary) on western 2-base-cell band; 1 (active interior).
    # Both the SFINCS water-level boundary AND the SnapWave wave boundary are
    # painted on the same western band so the tide and wave forcings are
    # simultaneously active over the same boundary cells.
    boundary_band_m = 2.0 * dx
    is_boundary = xc < (x0 + boundary_band_m)
    is_outside = (xc < x0) | (xc > x0 + mmax * dx) | (yc < y0) | (yc > y0 + nmax * dy)
    mask = np.full(nr_cells, 1, dtype=np.uint8)
    mask[is_boundary] = 2
    mask[is_outside] = 0
    grid["mask"] = xu.UgridDataArray(
        xr.DataArray(mask, dims=[grid.grid.face_dimension]),
        grid.grid,
    )

    snapwave_mask = np.full(nr_cells, 1, dtype=np.uint8)
    snapwave_mask[is_boundary] = 2
    snapwave_mask[is_outside] = 0
    grid["snapwave_mask"] = xu.UgridDataArray(
        xr.DataArray(snapwave_mask, dims=[grid.grid.face_dimension]),
        grid.grid,
    )

    print("Building synthetic DEM raster")
    dem = build_synthetic_dem(x0, y0, dx, dy, mmax, nmax, refi)

    elevation_list = [
        [{"da": dem, "merge_method": "first", "reproj_method": "bilinear"}]
        for _ in range(nr_levels_in_grid)
    ]

    print("Building subgrid tables (this can take a while)")
    import logging
    sbg_logger = logging.getLogger("hydromt_sfincs.subgrid")
    sbg_logger.setLevel(logging.INFO)
    if not sbg_logger.handlers:
        sbg_logger.addHandler(logging.StreamHandler())
    sbg_ds = build_subgrid_table_quadtree(
        grid=grid,
        elevation_list=elevation_list,
        roughness_list=[],
        manning_land=0.040,
        manning_water=0.020,
        manning_level=0.0,
        nr_levels=10,
        nr_subgrid_pixels=nr_subgrid_pixels,
        nrmax=2000,
        max_gradient=999.0,
        depth_factor=1.0,
        huthresh=0.01,
        weight_option="min",
        roughness_type="manning",
        buffer_cells=0,
        interp_method="linear",
        quiet=False,
        logger=sbg_logger,
    )

    qtr_path = out_dir / "sfincs.nc"
    print(f"Writing {qtr_path}")
    out_grid = grid.ugrid.to_dataset()
    out_grid["crs"] = crs.to_epsg()
    out_grid["crs"].attrs = crs.to_cf()
    if "dep" in out_grid:
        out_grid = out_grid.rename({"dep": "z"})
    out_grid.attrs = grid.attrs
    qtr_encoding = {v: {"zlib": True, "complevel": 4} for v in out_grid.data_vars}
    out_grid.to_netcdf(qtr_path, encoding=qtr_encoding)

    sbg_path = out_dir / "sfincs_subgrid.nc"
    print(f"Writing {sbg_path}")
    sbg_encoding = {v: {"zlib": True, "complevel": 4} for v in sbg_ds.data_vars}
    sbg_ds.to_netcdf(sbg_path, encoding=sbg_encoding)

    # Two boundary support points spanning the western edge — used both for
    # SFINCS sfincs.bnd / sfincs.bzs (tidal forcing) and for SnapWave
    # snapwave.bnd / snapwave.b{hs,tp,wd,ds} (wave-spectrum forcing).
    bnd_x = x0 + 0.5 * dx
    bnd_pts = [
        (bnd_x, y0 + 0.25 * nmax * dy),
        (bnd_x, y0 + 0.75 * nmax * dy),
    ]

    bnd_path = out_dir / "sfincs.bnd"
    print(f"Writing {bnd_path}")
    with bnd_path.open("w") as f:
        for x, y in bnd_pts:
            f.write(f"  {x:.2f}   {y:.2f}\n")

    # SFINCS tide: M2 (12.4206 h, 0.60 m) + M4 (6.2103 h, 0.15 m) + 0.20 m sea-level.
    print(f"Writing {out_dir / 'sfincs.bzs'}")
    t = np.arange(0.0, 24 * 3600.0 + 1.0, 1800.0)
    omega_m2 = 2 * np.pi / (12.4206 * 3600.0)
    omega_m4 = 2 * np.pi / (6.2103 * 3600.0)
    zs = 0.20 + 0.60 * np.sin(omega_m2 * t) + 0.15 * np.sin(omega_m4 * t + 0.6)
    with (out_dir / "sfincs.bzs").open("w") as f:
        for ti, zi in zip(t, zs):
            f.write(f"  {ti:9.1f}  {zi:9.4f}  {zi:9.4f}\n")

    sw_bnd_path = out_dir / "snapwave.bnd"
    print(f"Writing {sw_bnd_path}")
    with sw_bnd_path.open("w") as f:
        for x, y in bnd_pts:
            f.write(f"  {x:.2f}   {y:.2f}\n")

    # SnapWave time series, sampled every 30 min for 24 h. Identical at both
    # boundary support points so the wave-spectrum boundary is uniform along
    # the western edge but non-trivial in time (storm event).
    hs_t = storm_hs(t)
    tp_t = storm_tp(t)

    print(f"Writing {out_dir / 'snapwave.bhs'}")
    with (out_dir / "snapwave.bhs").open("w") as f:
        for ti, hi in zip(t, hs_t):
            f.write(f"  {ti:9.1f}  {hi:8.4f}  {hi:8.4f}\n")

    print(f"Writing {out_dir / 'snapwave.btp'}")
    with (out_dir / "snapwave.btp").open("w") as f:
        for ti, ti_p in zip(t, tp_t):
            f.write(f"  {ti:9.1f}  {ti_p:8.4f}  {ti_p:8.4f}\n")

    print(f"Writing {out_dir / 'snapwave.bwd'}")
    with (out_dir / "snapwave.bwd").open("w") as f:
        for ti in t:
            f.write(f"  {ti:9.1f}  270.0000  270.0000\n")

    print(f"Writing {out_dir / 'snapwave.bds'}")
    with (out_dir / "snapwave.bds").open("w") as f:
        for ti in t:
            f.write(f"  {ti:9.1f}   25.0000   25.0000\n")

    print(f"Done: {nr_cells} cells written to {out_dir}")
    print(f"  sfincs.nc          {qtr_path.stat().st_size / 1e6:.2f} MB")
    print(f"  sfincs_subgrid.nc  {sbg_path.stat().st_size / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
