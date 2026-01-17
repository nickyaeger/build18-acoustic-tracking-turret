import numpy as np
import matplotlib.pyplot as plt


# -----------------------------
# Geometry + propagation helpers
# -----------------------------
def make_geometry(mic_spacing=0.18, target=np.array([0.70, 0.25])):
    """Return origin, rx0, rx1, target positions (meters)."""
    origin = np.array([0.0, 0.0])
    rx0 = np.array([-mic_spacing / 2.0, 0.0])
    rx1 = np.array([+mic_spacing / 2.0, 0.0])
    return origin, rx0, rx1, np.array(target, dtype=float)


def distance(a, b):
    return float(np.linalg.norm(a - b))


def arrival_times(target, receivers, c=343.0):
    """Compute absolute time-of-flight to each receiver from target."""
    taus = np.array([distance(target, r) / c for r in receivers], dtype=float)
    return taus


# -----------------------------
# Signal generation + sampling
# -----------------------------
# def windowed_sinc_pulse(t, t0, width_s=0.00030, cycles=6):
#     """
#     Simple "noticeable spike": a windowed sinc-like pulse.
#     - width_s: controls main lobe width (smaller => sharper)
#     - cycles: number of main-lobe-ish widths included in the window
#     """
#     # Normalized time around pulse center
#     x = (t - t0) / width_s

#     # sinc pulse (np.sinc is sin(pi x)/(pi x))
#     s = np.sinc(x)

#     # Window to make it finite (Hann window over |x| <= cycles)
#     w = np.zeros_like(t)
#     mask = np.abs(x) <= cycles
#     # Hann window in x-domain
#     w[mask] = 0.5 * (1.0 + np.cos(np.pi * x[mask] / cycles))

#     return s * w


def windowed_sine_pulse(t, t0, freq_hz=2000.0, width_s=0.003, cycles=3):
    """
    Finite-duration sine burst.

    Args:
        t: time vector
        t0: center time of the burst
        freq_hz: sine frequency
        width_s: approximate half-width of the burst (controls duration)
        cycles: how many width_s units to include in the window

    Returns:
        windowed sine wave signal
    """
    # Shifted time axis around pulse center
    x = (t - t0) / width_s

    # Raw sine wave
    s = np.sin(2 * np.pi * freq_hz * (t - t0))

    # Hann window over |x| <= cycles
    w = np.zeros_like(t)
    mask = np.abs(x) <= cycles
    w[mask] = 0.5 * (1.0 + np.cos(np.pi * x[mask] / cycles))

    return s * w


def fractional_delay(signal, t, delay_s):
    """
    Apply a (possibly fractional) delay by sampling signal(t - delay).
    Uses linear interpolation for simplicity.
    """
    # want y(t) = x(t - delay) => sample original at shifted times
    t_shift = t - delay_s
    # Outside bounds -> 0
    return np.interp(t_shift, t, signal, left=0.0, right=0.0)


def make_capture_window(mic_spacing, c=343.0, capture_factor=4.0, fs=192_000):
    """
    Define the capture window:
      tmax = d/c  (max possible *inter-receiver* delay)
      Tcap = capture_factor * tmax
    Returns t vector, dt, tmax.
    """
    tmax = mic_spacing / c
    Tcap = capture_factor * tmax
    dt = 1.0 / fs
    # include endpoint? doesn't matter much; keep it simple
    t = np.arange(0.0, Tcap, dt)
    return t, dt, tmax


def simulate_capture(target, rx0, rx1, mic_spacing, c=343.0, fs=192_000):
    """
    Build discrete-time received waveforms at rx0 and rx1 for a single pulse.
    Returns dict with time axis and signals.
    """
    receivers = [rx0, rx1]

    # Capture window based on inter-receiver max delay
    t, dt, tmax = make_capture_window(mic_spacing, c=c, capture_factor=4.0, fs=fs)

    # Put the source pulse comfortably inside the window (avoid cropping)
    # Center it so we have pre/post room.
    t0 = 0.5 * (t[0] + t[-1])

    # Source pulse in "source time"
    # s_src = windowed_sinc_pulse(t, t0=t0, width_s=0.00030, cycles=6)
    s_src = windowed_sine_pulse(t, t0, freq_hz=6000.0, width_s=0.003, cycles=12)

    # Propagation: time-of-flight to each receiver
    taus = arrival_times(target, receivers, c=c)

    # Re-reference so RX0 arrival is at t=0
    taus_rel = taus - taus[0]  # [0, tau1 - tau0]

    # Optional: simple distance attenuation (1/r). Keep it, but clamp near 0.
    dists = np.array([distance(target, r) for r in receivers], dtype=float)

    # Received = attenuation * delayed(source)
    rx_sigs = []
    for k in range(2):
        y = fractional_delay(s_src, t, delay_s=taus_rel[k])
        rx_sigs.append(y)

    return {
        "t": t,
        "dt": dt,
        "tmax": tmax,
        "fs": fs,
        "source": s_src,
        "taus": taus,
        "rx0": rx_sigs[0],
        "rx1": rx_sigs[1],
        "dists": dists,
    }


# -----------------------------
# TDOA estimation
# -----------------------------


def estimate_tdoa_k(rx0, rx1, fs, tmax, center_index=None):
    rx0 = np.asarray(rx0)
    rx1 = np.asarray(rx1)
    assert rx0.shape == rx1.shape

    N = len(rx0)
    if center_index is None:
        center_index = N // 2

    K = int(np.floor(tmax * fs))

    n0 = max(0, center_index - K)
    n1 = min(N - 1, center_index + K)

    lags = np.arange(-K, K + 1, dtype=int)
    R = np.zeros_like(lags, dtype=float)

    for i, k in enumerate(lags):
        a0 = max(n0, 0 + k)
        a1 = min(n1, (N - 1) + k)
        if a1 < a0:
            continue

        x_seg = rx0[a0 : a1 + 1]
        y_seg = rx1[(a0 - k) : (a1 - k) + 1]

        R[i] = np.dot(x_seg, y_seg)

    k_hat = int(lags[np.argmax(R)])
    return k_hat, lags, R


def build_tdoa_lut(fs, mic_spacing, c=343.0, degrees=True):
    """
    Build LUT for k in [-K, +K] where K = floor((d/c)*fs).
    Returns dict with arrays indexed by (k + K).

    Mapping:
      dtau[k] = k/fs
      theta[k] = asin( clamp(c*dtau/d, -1, 1) )
    """
    tmax = mic_spacing / c
    K = int(np.floor(tmax * fs))

    ks = np.arange(-K, K + 1, dtype=int)  # possible lags
    dtau = ks / float(fs)  # seconds

    # plane wave far-field: sin(theta) = c*dtau/d
    sin_arg = (c * dtau) / float(mic_spacing)
    sin_arg = np.clip(sin_arg, -1.0, 1.0)

    theta = np.arcsin(sin_arg)  # radians
    if degrees:
        theta = np.degrees(theta)

    return {
        "fs": fs,
        "c": c,
        "d": mic_spacing,
        "tmax": tmax,
        "K": K,
        "ks": ks,
        "dtau": dtau,
        "theta": theta,  # degrees (if degrees=True) else radians
    }


def k_to_delay_and_angle(k_hat, lut):
    """
    Look up delay and angle for an estimated lag k_hat.
    Clamps k_hat into valid LUT range.
    """
    K = lut["K"]
    k_hat = int(np.clip(k_hat, -K, K))
    idx = k_hat + K
    return lut["dtau"][idx], lut["theta"][idx]


# -----------------------------
# Plotting
# -----------------------------


import numpy as np
import matplotlib.pyplot as plt


def plot_geometry(origin, rx0, rx1, target, theta_hat=None, degrees=True, ray_len=1.0):
    fig, ax = plt.subplots()
    ax.set_aspect("equal", "box")
    ax.grid(True, alpha=0.3)

    # Receivers
    ax.scatter(
        [rx0[0], rx1[0]], [rx0[1], rx1[1]], marker="^", s=120, label="Receivers (mics)"
    )
    ax.text(rx0[0] + 0.01, rx0[1] + 0.01, "RX0")
    ax.text(rx1[0] + 0.01, rx1[1] + 0.01, "RX1")

    # Origin (turret axis)
    ax.scatter(
        [origin[0]], [origin[1]], marker="+", s=220, linewidths=2, label="Turret origin"
    )
    ax.text(origin[0] + 0.01, origin[1] + 0.01, "Origin")

    # Target / source
    ax.scatter([target[0]], [target[1]], marker="o", s=120, label="Target (source)")
    ax.text(target[0] + 0.01, target[1] + 0.01, "Target")

    # True direction line (origin -> target)
    ax.plot(
        [origin[0], target[0]],
        [origin[1], target[1]],
        linestyle="--",
        linewidth=2,
        label="True direction",
    )

    # Predicted direction ray from theta_hat (measured from +y broadside)
    if theta_hat is not None:
        th = np.deg2rad(theta_hat) if degrees else float(theta_hat)

        # Broadside (+y) reference:
        # u = [sin(theta), cos(theta)]
        u = np.array([np.sin(th), np.cos(th)], dtype=float)

        p0 = origin
        p1 = origin + ray_len * u

        ax.plot(
            [p0[0], p1[0]],
            [p0[1], p1[1]],
            linestyle="-",
            linewidth=2,
            label=f"Predicted ray (θ̂={theta_hat:.1f}{'°' if degrees else ' rad'})",
        )

    # Axis limits (auto padded) include ray endpoint if present
    pts = [origin, rx0, rx1, target]
    if theta_hat is not None:
        pts.append(p1)
    pts = np.stack(pts, axis=0)

    xmin, ymin = pts.min(axis=0) - 0.2
    xmax, ymax = pts.max(axis=0) + 0.2
    ax.set_xlim(xmin, xmax)
    ax.set_ylim(ymin, ymax)

    ax.set_xlabel("x (m)")
    ax.set_ylabel("y (m)")
    ax.set_title("Geometry + true vs predicted direction")
    ax.legend()
    plt.show()


def stem_plot(ax, n, x, title):
    # A clean stem plot helper
    markerline, stemlines, baseline = ax.stem(n, x)
    ax.set_title(title)
    ax.set_xlabel("sample index n")
    ax.set_ylabel("amplitude")
    ax.grid(True, alpha=0.3)


def add_tmax_dividers(ax, t, tmax):
    """
    Draw vertical lines at t = k*tmax for k = -2,-1,0,1,2.
    Your stem x-axis is sample index n, so we convert those times to indices.
    """
    ks = [-2, -1, 0, 1, 2]
    for k in ks:
        tk = k * tmax
        idx = int(np.argmin(np.abs(t - tk)))  # closest sample index to that time
        ax.axvline(idx, linestyle="--", linewidth=1, alpha=0.5)


def plot_waveforms(sim, max_stem_samples=220):
    """
    Make discrete-time stem plots of the received signals.
    By default only stems the first ~220 samples so it stays readable.
    """
    t = sim["t"]
    fs = sim["fs"]
    x0 = sim["rx0"]
    x1 = sim["rx1"]
    s = sim["source"]
    tmax = sim["tmax"]

    n = np.arange(len(t))

    # Choose a readable window around the source pulse center.
    # Find where the source peak is, then plot +/- window around it.
    peak = int(np.argmax(np.abs(s)))
    half = max_stem_samples // 2
    lo = max(0, peak - half)
    hi = min(len(t), peak + half)

    fig, axs = plt.subplots(3, 1, figsize=(10, 8), constrained_layout=True)

    stem_plot(axs[0], n[lo:hi], s[lo:hi], "Discrete source pulse (stem)")
    add_tmax_dividers(axs[0], t, tmax)

    stem_plot(axs[1], n[lo:hi], x0[lo:hi], "RX0 capture (stem)")
    add_tmax_dividers(axs[1], t, tmax)

    stem_plot(axs[2], n[lo:hi], x1[lo:hi], "RX1 capture (stem)")
    add_tmax_dividers(axs[2], t, tmax)

    fig.suptitle(
        f"fs={fs:.0f} Hz | capture={t[-1]:.6f}s | taus=[{sim['taus'][0]:.6f}, {sim['taus'][1]:.6f}] s",
        fontsize=12,
    )
    plt.show()


# -----------------------------
# Main
# -----------------------------
def main():
    # ---- Config (meters) ----
    mic_spacing = 0.18
    target = np.array([0.70, 0.25])
    # target = np.array([7.00, 0.25])

    # ---- Geometry ----
    origin, rx0, rx1, target = make_geometry(mic_spacing=mic_spacing, target=target)

    # ---- Simulate discrete-time capture ----
    sim = simulate_capture(
        target=target,
        rx0=rx0,
        rx1=rx1,
        mic_spacing=mic_spacing,
        c=343.0,
        fs=192_000,  # keep high so the delay is well-resolved
    )

    k_hat, lags, R = estimate_tdoa_k(sim["rx0"], sim["rx1"], sim["fs"], sim["tmax"])
    print("k_hat (samples):", k_hat)
    print("tau_hat (seconds):", k_hat / sim["fs"])

    lut = build_tdoa_lut(fs=sim["fs"], mic_spacing=0.18, c=343.0, degrees=True)

    dtau_hat, theta_hat = k_to_delay_and_angle(k_hat, lut)

    print("dtau_hat (s):", dtau_hat)
    print("theta_hat (deg):", theta_hat)

    # ---- Plots ----
    plot_geometry(
        origin, rx0, rx1, target, theta_hat=theta_hat, degrees=True, ray_len=1.2
    )
    plot_waveforms(sim, max_stem_samples=403)

    # Quick prints (sanity)
    print("Distances (m):", sim["dists"])
    print("Arrival times taus (s):", sim["taus"])
    print("Inter-receiver theoretical tmax = d/c (s):", sim["tmax"])
    print("Measured delta tau (s):", float(sim["taus"][1] - sim["taus"][0]))


if __name__ == "__main__":
    main()
