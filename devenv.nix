{ config, pkgs, lib, ... }:

{
  imports = [
    ./darwin.devenv.nix
  ];

  languages.nix.enable = true;
  languages.kotlin.enable = true;

  languages.swift.enable = true;
  languages.dart.enable = true;
  languages.java = {
    jdk.package = lib.mkForce pkgs.jdk17;
  };

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

  packages = with pkgs; [
    git
    ripgrep
    melos
    bundletool
    android-studio-tools
  ];
}
