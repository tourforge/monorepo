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
  # Usage: devenv shell check-elf-alignment <app-name>
  scripts.check-elf-alignment.exec = ''
    if [ -z "$1" ]; then
      echo "Usage: check-elf-alignment <app-name>"
      exit 1
    fi
    APP_PATH="apps/$1"
    APK_PATH="$APP_PATH/build/app/outputs/flutter-apk/app-debug.apk"
    
    if [ ! -f "$APK_PATH" ]; then
      echo "Error: APK not found at $APK_PATH"
      echo "Ensure you have built the app first: devenv shell build-all-apk"
      exit 1
    fi

    ./scripts/check_elf_alignment.sh "$APK_PATH"
  '';

  pre-commit.hooks = {
    validate-workspace = {
      enable = true;
      name = "Workspace Integrity Audit";
      entry = "dart scripts/validate_workspace.dart";
      pass_filenames = false;
    };
    analyze = {
      enable = true;
      name = "Dart Analysis";
      entry = "dart analyze .";
      pass_filenames = false;
    };
  };
}
