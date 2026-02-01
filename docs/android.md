# Running paqet on Android (rooted)

paqet can run on **rooted** Android devices. The same binary acts as client or server depending on config. Android uses a Linux kernel, so the Linux code path applies; the main work is **building** the binary and **libpcap** for Android.

## Requirements

- **Rooted** Android device (Magisk, etc.).
- **Root/superuser** at runtime (raw sockets and pcap need it).
- **Wi‑Fi or cellular** interface you can use for the tunnel (e.g. `wlan0` or `rmnet_data0`).

## Build for Android

The repo includes a **Makefile** and **scripts** that build static **libpcap** for Android and then paqet. You need the **Android NDK** and build tools (flex, bison, autoconf, automake, libtool).

### Prerequisites (host)

- **Android NDK** (r25 or r26). Set `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` to the NDK root (e.g. after unzipping `android-ndk-r26-linux.zip`).
- **Go** 1.25+ with CGO enabled.
- **Build tools**: `flex`, `bison`, `autoconf`, `automake`, `libtool` (on Ubuntu/Debian: `apt install flex bison autoconf automake libtool`).

### Build with Make (recommended)

From the repo root:

```bash
# Build for arm64 (most devices)
make android-arm64
# Output: build/android/paqet_android_arm64

# Or build for 32-bit arm
make android-arm
# Output: build/android/paqet_android_arm

# Or build both
make android
```

### Build script only (libpcap)

To build libpcap for one ABI without the full paqet build:

```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r26
./scripts/build-libpcap-android.sh arm64-v8a   # or armeabi-v7a
```

### CI / Releases

On **push** or **tag**, the GitHub Actions workflow **Build and Release** runs `build-android` for `arm64-v8a` and `armeabi-v7a`. Artifacts are uploaded; on a version tag they are attached to the release. Download the tarball for your ABI and extract the binary and example configs.

### Build on your PC (Windows)

On Windows you need **Git Bash** (or **WSL**) to run `make` and the libpcap script.

1. **Install Android NDK for Windows**  
   Download from [developer.android.com/ndk/downloads](https://developer.android.com/ndk/downloads) (e.g. `android-ndk-r26-windows.zip`), extract to e.g. `C:\android-ndk-r26`.

2. **Set the NDK path**
   - PowerShell: `$env:ANDROID_NDK_HOME = "C:\android-ndk-r26"`
   - Git Bash: `export ANDROID_NDK_HOME="/c/android-ndk-r26"`

3. **Install build tools for libpcap**  
   In Git Bash you need `make`, `flex`, `bison`, `autoconf`, `automake`, `libtool`. The easiest way is **MSYS2**: install MSYS2, open “MSYS2 MSYS”, run:
   ```bash
   pacman -S make flex bison autoconf automake libtool git
   ```
   Then use the MSYS2 bash and add Go to PATH, or use Git Bash if you have make/flex/bison from another source.

4. **Run the build**
   - **Option A – PowerShell helper:**  
     From the repo root: `.\scripts\build-android-pc.ps1`  
     (Uses `bash` from Git Bash if in PATH and runs `make android-arm64`.)
   - **Option B – Git Bash or MSYS2:**  
     ```bash
     cd /c/Users/.../paqet   # your repo path
     export ANDROID_NDK_HOME="/c/android-ndk-r26"
     make android-arm64
     ```
   - **Option C – WSL:**  
     Use the Linux instructions inside WSL; install the Linux NDK there and run `make android-arm64`.

The Makefile and script support **Windows** as host (NDK `windows-x86_64` and `.exe` compilers).

### Copy binary to device

Binaries are under `build/android/` (or `build\android\` on Windows). Example:

```bash
adb push build/android/paqet_android_arm64 /data/local/tmp/paqet
adb shell chmod +x /data/local/tmp/paqet
```

## Config on Android (client example)

1. **Interface**: Use the interface that has the IP you want to use:
   - **Wi‑Fi**: usually `wlan0`
   - **Cellular**: often `rmnet_data0` or similar (check with `ip link` or `ifconfig` in a root shell).

2. **Your IP and gateway**:
   - In a root shell: `ip addr` and `ip route` (or `ifconfig` and `netstat -rn`).
   - Set `network.ipv4.addr` to the device’s IP and port `0` for client (e.g. `192.168.1.10:0`).
   - Get the **gateway MAC** (router/Wi‑Fi AP or cellular gateway):
     ```bash
     # As root on device (e.g. via adb shell)
     ip neigh show
     ```

3. **Server**: Set `server.addr` to your paqet server (e.g. `your-server-ip:9999`).

4. **KCP key**: Must match the server (`transport.kcp.key`); generate with `./paqet secret` on a PC and put the same key in client and server configs.

Example **client** snippet for Android (Wi‑Fi):

```yaml
role: "client"
network:
  interface: "wlan0"
  ipv4:
    addr: "192.168.1.10:0"        # device IP, port 0
    router_mac: "aa:bb:cc:dd:ee:ff"  # gateway MAC from ip neigh / arp
server:
  addr: "YOUR_SERVER_IP:9999"
transport:
  protocol: "kcp"
  kcp:
    block: "aes"
    key: "your-shared-secret"
socks5:
  - listen: "127.0.0.1:1080"
```

Save as e.g. `config.yaml` and push to the device:

```bash
adb push config.yaml /data/local/tmp/
```

## Run on device

1. **Root shell** (required for pcap/raw sockets):

   ```bash
   adb shell
   su
   cd /data/local/tmp
   ```

2. **Run client**:

   ```bash
   ./paqet run -c config.yaml
   ```

3. **Use SOCKS5** from the same device (or over ADB port-forward):
   - Proxy: `127.0.0.1:1080` (or the IP of the device if testing from another app on the same device).

4. **Optional – port-forward for testing from PC**:

   ```bash
   adb forward tcp:1080 tcp:1080
   # On PC: curl -x socks5h://127.0.0.1:1080 https://httpbin.org/ip
   ```
