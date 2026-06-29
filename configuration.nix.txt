{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ============================================================
  # UNFREE PACKAGES (Chrome, VSCode)
  # ============================================================
  nixpkgs.config.allowUnfree = true;

  # ============================================================
  # BOOT
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 2;
  boot.loader.efi.canTouchEfiVariables = true;

  # ============================================================
  # FLAKES
  # ============================================================
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ============================================================
  # NETWORK
  # ============================================================
  networking.hostName = "km-laptop";
  networking.networkmanager.enable = true;

  # ============================================================
  # TIMEZONE & LOCALE
  # ============================================================
  time.timeZone = "Africa/Cairo";
  i18n.defaultLocale = "en_US.UTF-8";

  # ============================================================
  # DISPLAY - WAYLAND + HYPRLAND
  # ============================================================
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Login Manager
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # XDG Portal (مهم لـ Wayland)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  # ============================================================
  # AUDIO - PIPEWIRE
  # ============================================================
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ============================================================
  # BLUETOOTH
  # ============================================================
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ============================================================
  # HARDWARE - INTEL IRIS XE
  # ============================================================
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # ============================================================
  # STM32 / EMBEDDED DEVELOPMENT
  # ============================================================
  services.udev.packages = [ pkgs.openocd ];

  # USB access for STM32
  users.groups.plugdev = {};

  # ============================================================
  # SYSTEM PACKAGES (system-wide)
  # ============================================================
  environment.systemPackages = with pkgs; [
    # Core tools
    wget
    curl
    git
    vim
    htop

    # Embedded / STM32
    gcc-arm-embedded
    openocd
    minicom
    stlink

    # Wayland essentials
    xwayland
    wl-clipboard
    brightnessctl
    grim
    slurp

    # Network
    networkmanagerapplet
  ];

  # ============================================================
  # USER
  # ============================================================
  users.users.km = {
    isNormalUser = true;
    description = "km";
    password = "km";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "dialout"   # للـ serial port (STM32)
      "plugdev"   # للـ USB (STM32)
    ];
  };

  # sudo بدون password (اختياري)
  security.sudo.wheelNeedsPassword = false;

  # ============================================================
  # SSH
  # ============================================================
  services.openssh.enable = true;

  # ============================================================
  # FONTS
  # ============================================================
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-arabic
    fira-code
    fira-code-symbols
    (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
  ];

  system.stateVersion = "24.11";
}
