#!/usr/bin/env python3
# Deterministic generator for case_prod_riverine inputs.
#
# Produces, from a fixed RNG seed:
#   sfincs.dep   — bathymetry (ASCII, nmax rows x mmax cols)
#   sfincs.msk   — mask (ASCII, nmax rows x mmax cols, 0/1/2)
#   sfincs.bnd   — boundary support points (ASCII, x y per line)
#   sfincs.bzs   — boundary water-level time series (ASCII, t z1 z2 ...)
#   sfincs.src   — source point coordinates (ASCII, x y per line)
#   sfincs.dis   — source discharge time series (ASCII, t q1 q2 ...)
#   sfincs.weir  — weir polyline (Delft3D thin-dam style ASCII)
#   sfincs.scs   — SCS Curve Number method-A retention raster S (binary float32)
#   sfincs.prcp  — uniform-in-space precipitation time series (ASCII, t mm/hr)
#
# All files land next to this script. Re-running overwrites them with byte-for-byte
# identical contents (the seed is fixed; numpy.random.default_rng is deterministic).
#
# Run from this directory:
#   python3 generate.py

import os
import struct

import numpy as np

# --- Grid -------------------------------------------------------------------

MMAX = 400              # number of cells in x direction (columns)
NMAX = 400              # number of cells in y direction (rows)
DX = 50.0               # cell size in metres
DY = 50.0
X0 = 0.0
Y0 = 0.0
ROTATION = 0.0

# --- Time window ------------------------------------------------------------

# 24-hour run. tref / tstart / tstop are written into sfincs.inp directly;
# the time-series files are in seconds since tref.
T_REF_STR = "20200101 000000"
T_START_STR = "20200101 000000"
T_STOP_STR = "20200102 000000"          # +24 h
SIM_LEN_S = 24 * 3600                   # 86 400 s; ~22 000 adaptive-CFL steps

# --- Boundary forcing -------------------------------------------------------

BND_Y_M = [2500.0, 10000.0, 17500.0]    # 3 boundary support points along x = 0
M2_PERIOD_S = 12.42 * 3600
M4_PERIOD_S = 6.21 * 3600
M2_AMP_M = 0.6
M4_AMP_M = 0.15
SEA_LEVEL_M = 0.05
BND_DT_S = 1800.0                       # bzs sample every 30 min

# --- Source / discharge -----------------------------------------------------

# One source cell at the upstream (east) end of the river channel.
# The river runs at y = 10 000 m, so place the source at the easternmost
# in-channel cell. (Cell-centred; m = 395 → x = 19 725 m.)
SRC_X_M = 19725.0
SRC_Y_M = 10000.0

# Stepped hydrograph (m^3/s). Baseflow → peak → recession.
DIS_TIMES_S = np.array(
    [0.0, 4 * 3600, 4.5 * 3600, 14 * 3600, 14.5 * 3600, 22 * 3600, SIM_LEN_S],
)
DIS_VALUES_M3S = np.array([5.0, 5.0, 50.0, 50.0, 8.0, 5.0, 5.0])

# --- Weir -------------------------------------------------------------------

# A polyline crossing the river midway between source (east) and the tide
# boundary (west). 4 vertices, crest 1.0 m, discharge coefficient 0.6.
WEIR_VERTICES_XY = [
    (10000.0, 9500.0),
    (10000.0, 9900.0),
    (10000.0, 10100.0),
    (10000.0, 10500.0),
]
WEIR_CREST_M = 1.0
WEIR_CD = 0.6

# --- Infiltration (SCS Curve Number method A) -------------------------------

# Three CN zones over the domain:
#   * default: CN = 80 (typical agricultural)
#   * x in [3000, 5500] m strip: CN = 95 (impervious)
#   * x in [12000, 14500] m strip: CN = 65 (forested)
# Stored as the maximum potential retention S = (1000/CN - 10) inches,
# matching the binary scsfile format consumed by source/src/sfincs_infiltration_io.f90
# inftype = 'cna' (read as inches, multiplied by 0.0254 to convert to metres).

CN_DEFAULT = 80.0
CN_IMPERVIOUS = 95.0
CN_FORESTED = 65.0


def cn_to_s_inches(cn):
    return 1000.0 / cn - 10.0


# --- Precipitation ----------------------------------------------------------

# Moderate storm pulse: 2 mm/hr from t = 2 h to t = 12 h, zero elsewhere.
# This activates the SCS infiltration path (precip is a hard precondition for
# infiltration in source/src/sfincs_infiltration_io.f90) and accumulates a
# meaningful runoff coefficient over the simulation window.
PRECIP_TIMES_S = np.array(
    [0.0, 2 * 3600, 2 * 3600 + 1, 12 * 3600, 12 * 3600 + 1, SIM_LEN_S],
)
PRECIP_VALUES_MMHR = np.array([0.0, 0.0, 2.0, 2.0, 0.0, 0.0])

# ---------------------------------------------------------------------------
# Bathymetry
# ---------------------------------------------------------------------------


def build_bathymetry():
    rng = np.random.default_rng(seed=20260509)
    n_idx = np.arange(NMAX)                 # 0..NMAX-1 (rows)
    m_idx = np.arange(MMAX)                 # 0..MMAX-1 (cols)
    nn, mm = np.meshgrid(n_idx, m_idx, indexing="ij")  # shape (NMAX, MMAX)

    y = Y0 + (nn + 0.5) * DY                # cell-centre y

    # Linear east-to-west slope: -3 m at west edge → +5 m at east edge.
    x_frac = mm / (MMAX - 1)
    zb = -3.0 + 8.0 * x_frac

    # River channel: a 200 m wide trough centred on y = 10 000 m, depressed
    # below the local slope by up to 1.5 m, tapered with a cosine profile.
    half_width = 200.0
    y_dist = np.abs(y - 10000.0)
    in_channel = y_dist < half_width
    profile = np.where(
        in_channel,
        1.5 * np.cos(0.5 * np.pi * y_dist / half_width) ** 2,
        0.0,
    )
    zb -= profile

    # Add small deterministic roughness so the field isn't perfectly smooth
    # (helps exercise downstream code paths that branch on cell-to-cell
    # gradients). ±5 cm uniform noise, fixed seed.
    zb += rng.uniform(-0.05, 0.05, size=zb.shape).astype(np.float32)

    return zb.astype(np.float32)


# ---------------------------------------------------------------------------
# Mask
# ---------------------------------------------------------------------------


def build_mask():
    msk = np.ones((NMAX, MMAX), dtype=np.int32)
    msk[:, 0] = 2                           # west column = open boundary
    return msk


# ---------------------------------------------------------------------------
# Boundary water-level forcing (M2 + M4 + sea-level)
# ---------------------------------------------------------------------------


def build_bzs(times_s):
    omega2 = 2.0 * np.pi / M2_PERIOD_S
    omega4 = 2.0 * np.pi / M4_PERIOD_S
    rng = np.random.default_rng(seed=20260510)
    # Per-point phase offsets so the three boundary points see slightly
    # different signals (avoids a perfectly correlated boundary that would
    # collapse to a single 1-D forcing).
    phases = rng.uniform(0.0, 2.0 * np.pi, size=len(BND_Y_M))
    z = np.empty((len(times_s), len(BND_Y_M)), dtype=np.float32)
    for j, ph in enumerate(phases):
        z[:, j] = (
            SEA_LEVEL_M
            + M2_AMP_M * np.sin(omega2 * times_s + ph)
            + M4_AMP_M * np.sin(omega4 * times_s + 2 * ph)
        )
    return z


# ---------------------------------------------------------------------------
# SCS retention raster (binary float32, np values, m-outer / n-inner)
# ---------------------------------------------------------------------------


def build_scs(msk):
    # CN field over the full grid, then strip down to active mask in the
    # iteration order SFINCS uses for the binary scsfile (m outer, n inner).
    n_idx = np.arange(NMAX)
    m_idx = np.arange(MMAX)
    nn, mm = np.meshgrid(n_idx, m_idx, indexing="ij")
    x = X0 + (mm + 0.5) * DX

    cn = np.full((NMAX, MMAX), CN_DEFAULT, dtype=np.float32)
    cn[(x >= 3000.0) & (x < 5500.0)] = CN_IMPERVIOUS
    cn[(x >= 12000.0) & (x < 14500.0)] = CN_FORESTED

    s_inches = cn_to_s_inches(cn).astype(np.float32)

    flat = []
    for m in range(MMAX):
        for n in range(NMAX):
            if msk[n, m] > 0:
                flat.append(s_inches[n, m])
    return np.array(flat, dtype=np.float32)


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------


def write_grid_ascii(path, arr, fmt):
    with open(path, "w") as f:
        for n in range(arr.shape[0]):
            row = arr[n, :]
            f.write(" ".join(fmt.format(v) for v in row) + "\n")


def write_bnd(path):
    with open(path, "w") as f:
        for y in BND_Y_M:
            f.write(f"{X0:.1f} {y:.1f}\n")


def write_bzs(path, times_s, z):
    with open(path, "w") as f:
        for i, t in enumerate(times_s):
            row = " ".join(f"{v:.6f}" for v in z[i, :])
            f.write(f"{t:.1f} {row}\n")


def write_src(path):
    with open(path, "w") as f:
        f.write(f"{SRC_X_M:.1f} {SRC_Y_M:.1f}\n")


def write_dis(path):
    with open(path, "w") as f:
        for t, q in zip(DIS_TIMES_S, DIS_VALUES_M3S):
            f.write(f"{t:.1f} {q:.4f}\n")


def write_weir(path):
    with open(path, "w") as f:
        f.write("weir01\n")
        f.write(f"{len(WEIR_VERTICES_XY)} 4\n")
        for x, y in WEIR_VERTICES_XY:
            f.write(f"{x:.2f} {y:.2f} {WEIR_CREST_M:.3f} {WEIR_CD:.3f}\n")


def write_scs(path, arr):
    with open(path, "wb") as f:
        f.write(arr.astype("<f4").tobytes())


def write_prcp(path):
    with open(path, "w") as f:
        for t, p in zip(PRECIP_TIMES_S, PRECIP_VALUES_MMHR):
            f.write(f"{t:.1f} {p:.4f}\n")


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


def main():
    here = os.path.dirname(os.path.abspath(__file__))

    zb = build_bathymetry()
    msk = build_mask()
    scs = build_scs(msk)

    # Bzs samples every BND_DT_S over the run window plus an end-cap.
    n_steps = int(np.ceil(SIM_LEN_S / BND_DT_S)) + 1
    times_s = np.arange(n_steps, dtype=np.float64) * BND_DT_S
    z_bnd = build_bzs(times_s)

    write_grid_ascii(os.path.join(here, "sfincs.dep"), zb, "{:.4f}")
    write_grid_ascii(os.path.join(here, "sfincs.msk"), msk, "{:d}")
    write_bnd(os.path.join(here, "sfincs.bnd"))
    write_bzs(os.path.join(here, "sfincs.bzs"), times_s, z_bnd)
    write_src(os.path.join(here, "sfincs.src"))
    write_dis(os.path.join(here, "sfincs.dis"))
    write_weir(os.path.join(here, "sfincs.weir"))
    write_scs(os.path.join(here, "sfincs.scs"), scs)
    write_prcp(os.path.join(here, "sfincs.prcp"))

    # Quick sanity report so a human running the generator can confirm shapes.
    np_active = int((msk > 0).sum())
    print(f"grid             : {NMAX} rows x {MMAX} cols at {DX:g} m")
    print(f"active z points  : {np_active}")
    print(f"bzs samples      : {len(times_s)} over {SIM_LEN_S/3600:.1f} h")
    print(f"discharge samples: {len(DIS_TIMES_S)}")
    print(f"weir vertices    : {len(WEIR_VERTICES_XY)}")
    print(f"scs raster size  : {scs.size} x float32 = {scs.nbytes} bytes")


if __name__ == "__main__":
    main()
