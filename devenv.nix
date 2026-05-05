{ config, pkgs, lib, ... }:

{
  languages.nix.enable = true;
  languages.kotlin.enable = true;

  languages.swift.enable = true;
  languages.dart.enable = true;
  languages.java = {
    jdk.package = lib.mkForce pkgs.jdk17;
  };

  scripts.create-emulator.exec = "avdmanager create avd --force --name TourForge_AVD --package 'system-images;android-35;google_apis_playstore;arm64-v8a'";
  
  enterShell = ''
    # Check for the emulator after the environment is fully initialized
    if command -v emulator >/dev/null; then
      if ! emulator -list-avds 2>/dev/null | grep -q "TourForge_AVD"; then
        echo ""
        echo "⚠️  TourForge_AVD not found."
        echo "   Run 'create-emulator' to initialize the project-standard emulator."
        echo ""
      fi
    fi
  '';

  packages = with pkgs; [
    git
    ripgrep
    melos
    bundletool
    android-studio-tools
  ];

  android = {
    enable = true;
    flutter.enable = true;
    
    buildTools.version = [
      "35.0.0-rc3"
      "35.0.0"
    ];

    extraLicenses = [
      "android-sdk-preview-license"
      "android-googletv-license"
      "android-sdk-arm-dbt-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
      "android-googlexr-license"
    ];

    platforms.version = [
      "35"
      "36"
    ];
    
    ndk.enable = true;
    ndk.version = [ "29.0.14206865" ];

    emulator.enable = true;
  };
}
