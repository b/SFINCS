#!/usr/bin/env python3
"""Deterministic generator for the case_prod_storm_amuv inputs.

Emits every file referenced by sfincs.inp from a fixed parameter set so the
case is fully reproducible from this script alone:

    sfincs.dep      400x400 ASCII bathymetry
    sfincs.msk      400x400 ASCII mask (msk=2 west boundary column, msk=1 inside)
    sfincs.bnd      3 western support points
    sfincs.bzs      M2+M4 tide + slow storm-surge ramp at the 3 support points
    sfincs.prcp     uniform-in-space precipitation time series
    sfincs.amu      gridded x-component wind (drifting front)
    sfincs.amv      gridded y-component wind (smooth meridional gradient)
    sfincs.psi      Green-Ampt suction head [mm], binary float32 stream (np)
    sfincs.sigma    Green-Ampt max moisture deficit, binary float32 stream (np)
    sfincs.ks       Green-Ampt saturated conductivity [mm/hr], binary float32 stream (np)

Run from the case directory:

    python3 generate.py

Re-running overwrites the generated files in place; the case directory is
the single source of truth, the script is the recipe.
"""

import os
import struct
import sys
from pathlib import Path

import numpy as np

CASE_DIR = Path(__file__).resolve().parent

# --- Mesh parameters --------------------------------------------------------
# 400x400 cells at 50 m -> 20 km x 20 km footprint, 160_000 mask cells.
NMAX = 400          # number of rows (n direction, y axis)
MMAX = 400          # number of columns (m direction, x axis)
DX = 50.0           # cell size, m
DY = 50.0
X0 = 0.0
Y0 = 0.0

# --- Time window ------------------------------------------------------------
# 24 simulated hours: low-end of the issue's 24-36 h range, picked so a
# CPU baseline run on a contended dev box completes inside the harness's
# practical budget while still yielding ~30 000 timesteps.
SIM_HOURS = 24.0
SIM_SECONDS = SIM_HOURS * 3600.0


# --- Bathymetry -------------------------------------------------------------
def make_bathymetry():
    """Linear coastal-shelf ramp from -8 m offshore (west) to +2 m onshore (east).

    Shape: (NMAX, MMAX) where the m index runs west->east. The ramp is
    purely a function of m so wind- and tide-driven flow has a meaningful
    gradient to push against, while every cell stays within the dynamic
    range of the boundary forcing + storm-surge so the case keeps a high
    active-wet-cell count.
    """
    z_west = -8.0
    z_east = 2.0
    m = np.arange(MMAX, dtype=np.float64)
    z_row = z_west + (z_east - z_west) * (m / (MMAX - 1))
    z = np.broadcast_to(z_row, (NMAX, MMAX)).copy()
    return z


def make_mask():
    """Mask: msk=2 on the western column (water-level boundary), msk=1 elsewhere.

    Total active cells = NMAX * MMAX = 160_000 (every cell has msk > 0).
    """
    msk = np.ones((NMAX, MMAX), dtype=np.int32)
    msk[:, 0] = 2
    return msk


# --- Boundary forcing -------------------------------------------------------
def make_boundary_points():
    """Three support points along the western edge."""
    return np.array(
        [
            [X0, Y0],
            [X0, Y0 + 0.5 * NMAX * DY],
            [X0, Y0 + (NMAX - 1) * DY],
        ],
        dtype=np.float64,
    )


def make_boundary_timeseries():
    """M2 + M4 + storm-surge water-level signal sampled at 30 min intervals.

    Three identical columns (one per support point) so the western boundary is
    excited uniformly along its length.
    """
    dt = 1800.0  # 30 minutes
    t = np.arange(0.0, SIM_SECONDS + dt / 2, dt)

    M2_period = 12.42 * 3600.0  # principal lunar semidiurnal
    M2_amp = 0.70
    M4_period = 6.21 * 3600.0
    M4_amp = 0.20
    surge_amp = 0.50
    surge_t0 = 12.0 * 3600.0
    surge_sigma = 3.0 * 3600.0

    tide = (
        M2_amp * np.sin(2 * np.pi * t / M2_period)
        + M4_amp * np.sin(2 * np.pi * t / M4_period + 0.5 * np.pi)
    )
    surge = surge_amp * np.exp(-0.5 * ((t - surge_t0) / surge_sigma) ** 2)
    zs = tide + surge
    return t, zs


# --- Precipitation ----------------------------------------------------------
def make_precip_timeseries():
    """Triangular rainfall pulse with peak at mid-simulation.

    Returns (t [s], rate [mm/hr]).
    """
    dt = 1800.0
    t = np.arange(0.0, SIM_SECONDS + dt / 2, dt)
    peak_rate = 8.0  # mm/hr
    peak_t = 12.0 * 3600.0
    half_width = 6.0 * 3600.0
    rate = np.maximum(0.0, peak_rate * (1.0 - np.abs(t - peak_t) / half_width))
    return t, rate


# --- Wind fields ------------------------------------------------------------
WIND_NCOLS = 41
WIND_NROWS = 41
WIND_DX = (MMAX * DX) / (WIND_NCOLS - 1)
WIND_DY = (NMAX * DY) / (WIND_NROWS - 1)
WIND_TIMES_HOURS = np.array([0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0])


def _wind_grid_xy():
    xs = X0 + np.arange(WIND_NCOLS, dtype=np.float64) * WIND_DX
    ys = Y0 + np.arange(WIND_NROWS, dtype=np.float64) * WIND_DY
    return np.meshgrid(xs, ys)


def make_wind_u_fields():
    """x-component wind: drifting wind front with a persistent x-gradient.

    Two structural features both contribute to the spatial gradient at every
    snapshot:
      * a background west-to-east ramp (u increases by ~5 m/s across the
        domain), so even the bookend snapshots have a non-trivial gradient;
      * a tanh wind front that drifts south through the domain, with the
        northern side stronger than the southern side. The front is the
        dominant feature for most of the run.
    """
    X, Y = _wind_grid_xy()
    L_x = MMAX * DX
    u_low = 10.0
    u_high = 25.0
    bg_amp = 5.0
    transition = 1500.0  # m, tanh half-width
    # Keep the front inside the domain for the full window so every snapshot
    # carries a non-trivial spatial gradient from the front itself.
    yf_start = Y0 + (NMAX - 1) * DY - 1000.0
    yf_end = Y0 + 1000.0
    fields = []
    Tmax = WIND_TIMES_HOURS[-1] * 3600.0
    for h in WIND_TIMES_HOURS:
        ts = h * 3600.0
        yf = yf_start + (yf_end - yf_start) * (ts / Tmax)
        bg = bg_amp * (X / L_x)
        front = 0.5 * (u_high - u_low) * (1.0 + np.tanh((Y - yf) / transition))
        u = u_low + bg + front
        fields.append(u.astype(np.float32))
    return np.stack(fields, axis=0)


def make_wind_v_fields():
    """y-component wind: meridional sinusoidal gradient with time-varying amp.

    A constant southward bias plus a sin(2 pi x / Lx) pattern whose amplitude
    ramps from ~1 m/s at t=0 to ~6 m/s at the end. Both pieces are spatially
    non-trivial at every snapshot, and the time-evolving amplitude gives the
    field genuine temporal structure independent of the front in amu.
    """
    X, _Y = _wind_grid_xy()
    L_x = MMAX * DX
    v_bias = -2.0
    v_amp_min = 1.0
    v_amp_max = 6.0
    fields = []
    Tmax = WIND_TIMES_HOURS[-1] * 3600.0
    for h in WIND_TIMES_HOURS:
        ts = h * 3600.0
        amp = v_amp_min + (v_amp_max - v_amp_min) * (ts / Tmax)
        v = v_bias + amp * np.sin(2 * np.pi * X / L_x)
        fields.append(v.astype(np.float32))
    return np.stack(fields, axis=0)


# --- Green-Ampt soil rasters ------------------------------------------------
def make_green_ampt_rasters(msk):
    """Two-zone soil pattern (sandy north / clayey south) with a wavy boundary.

    Returns three (NMAX, MMAX) float32 arrays in mask iteration order:
    psi [mm], sigma [-], ks [mm/hr]. Active cells with msk > 0 are
    flattened later into the np-sized binary streams the SFINCS reader
    expects.
    """
    n = np.arange(NMAX, dtype=np.float64)
    m = np.arange(MMAX, dtype=np.float64)
    M, N = np.meshgrid(m, n)
    L_x = MMAX * DX
    boundary_n = 0.5 * NMAX + 30.0 * np.sin(2 * np.pi * (M * DX) / L_x)
    sandy = (N > boundary_n).astype(np.float32)

    psi_sandy, psi_clay = 50.0, 220.0
    sigma_sandy, sigma_clay = 0.30, 0.40
    ks_sandy, ks_clay = 50.0, 3.0

    psi = (psi_sandy * sandy + psi_clay * (1.0 - sandy)).astype(np.float32)
    sigma = (sigma_sandy * sandy + sigma_clay * (1.0 - sandy)).astype(np.float32)
    ks = (ks_sandy * sandy + ks_clay * (1.0 - sandy)).astype(np.float32)
    return psi, sigma, ks


# --- File writers -----------------------------------------------------------
def write_dep(path, z):
    with open(path, "w") as f:
        for n in range(NMAX):
            f.write(" ".join(f"{val:7.2f}" for val in z[n]) + "\n")


def write_msk(path, msk):
    with open(path, "w") as f:
        for n in range(NMAX):
            f.write(" ".join(f"{val:d}" for val in msk[n]) + "\n")


def write_bnd(path, points):
    with open(path, "w") as f:
        for x, y in points:
            f.write(f"{x:.2f} {y:.2f}\n")


def write_bzs(path, t, zs, ncols):
    with open(path, "w") as f:
        for ti, zi in zip(t, zs):
            cols = " ".join(f"{zi:8.4f}" for _ in range(ncols))
            f.write(f"{ti:10.1f} {cols}\n")


def write_prcp(path, t, rate):
    with open(path, "w") as f:
        for ti, ri in zip(t, rate):
            f.write(f"{ti:10.1f} {ri:8.4f}\n")


def write_amuv(path, fields, quantity, unit):
    """Delft3D-style equidistant-grid meteo file: header + per-time blocks."""
    nt = fields.shape[0]
    with open(path, "w") as f:
        f.write("FileVersion      = 1.03\n")
        f.write("filetype         = meteo_on_equidistant_grid\n")
        f.write("NODATA_value     = -999.000\n")
        f.write(f"n_cols           = {WIND_NCOLS}\n")
        f.write(f"n_rows           = {WIND_NROWS}\n")
        f.write("grid_unit        = m\n")
        f.write(f"x_llcorner       = {X0}\n")
        f.write(f"y_llcorner       = {Y0}\n")
        f.write(f"dx               = {WIND_DX}\n")
        f.write(f"dy               = {WIND_DY}\n")
        f.write("n_quantity       = 1\n")
        f.write(f"quantity1        = {quantity}\n")
        f.write(f"unit1            = {unit}\n")
        for it in range(nt):
            h = WIND_TIMES_HOURS[it]
            f.write(
                f"TIME = {h:.4f} hours since 2020-01-01 00:00:00 +00:00\n"
            )
            grid = fields[it]
            for n in range(WIND_NROWS):
                row = " ".join(f"{val:7.3f}" for val in grid[n])
                f.write(row + "\n")


def write_binary_stream(path, arr_full, msk):
    """Write float32 stream for the active-cell ordering SFINCS expects.

    Mask iteration order from sfincs_domain.f90: outer loop m (=column),
    inner loop n (=row), counted only where kcsg(n,m) > 0.
    """
    flat = []
    for m in range(MMAX):
        for n in range(NMAX):
            if msk[n, m] > 0:
                flat.append(arr_full[n, m])
    arr = np.asarray(flat, dtype=np.float32)
    with open(path, "wb") as f:
        f.write(arr.tobytes())


# --- Main -------------------------------------------------------------------
def main():
    z = make_bathymetry()
    msk = make_mask()

    write_dep(CASE_DIR / "sfincs.dep", z)
    write_msk(CASE_DIR / "sfincs.msk", msk)

    bnd = make_boundary_points()
    write_bnd(CASE_DIR / "sfincs.bnd", bnd)
    bzs_t, bzs_zs = make_boundary_timeseries()
    write_bzs(CASE_DIR / "sfincs.bzs", bzs_t, bzs_zs, ncols=len(bnd))

    prcp_t, prcp_rate = make_precip_timeseries()
    write_prcp(CASE_DIR / "sfincs.prcp", prcp_t, prcp_rate)

    u_fields = make_wind_u_fields()
    v_fields = make_wind_v_fields()
    write_amuv(CASE_DIR / "sfincs.amu", u_fields, "x_wind", "m s-1")
    write_amuv(CASE_DIR / "sfincs.amv", v_fields, "y_wind", "m s-1")

    psi, sigma, ks = make_green_ampt_rasters(msk)
    write_binary_stream(CASE_DIR / "sfincs.psi", psi, msk)
    write_binary_stream(CASE_DIR / "sfincs.sigma", sigma, msk)
    write_binary_stream(CASE_DIR / "sfincs.ks", ks, msk)

    np_active = int((msk > 0).sum())
    print(f"NMAX={NMAX} MMAX={MMAX} dx=dy={DX} m  np_active={np_active}")
    print(f"Simulation window: {SIM_HOURS:.0f} h")
    total_bytes = 0
    for name in (
        "sfincs.dep",
        "sfincs.msk",
        "sfincs.bnd",
        "sfincs.bzs",
        "sfincs.prcp",
        "sfincs.amu",
        "sfincs.amv",
        "sfincs.psi",
        "sfincs.sigma",
        "sfincs.ks",
    ):
        p = CASE_DIR / name
        size = p.stat().st_size
        total_bytes += size
        print(f"  {name:<14s} {size:>10d} bytes")
    print(f"Total in-tree size of inputs: {total_bytes / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
