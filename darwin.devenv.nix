{ config, pkgs, lib, ... }:

lib.mkIf (config.stdenv.buildPlatform.isDarwin) {
  packages = with pkgs; [
    cocoapods
    xcodes
  ];

  # No support for x86 on arm darwins for now, reduces build time and space
  android.abis = [
    "arm64-v8a"
  ];

  # Slight harm to reproducibility for local dev speed
  apple.sdk = null;
  env.DEVELOPER_DIR = "";
  env.SDKROOT = "";
  env.NIX_APPLE_SDK_VERSION = "";
}
