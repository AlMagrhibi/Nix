{ config, pkgs, ... }:

{
  home.username = "km";
  home.homeDirectory = "/home/km";
  home.stateVersion = "24.11";

  # ============================================================
  # USER PACKAGES
  # ============================================================
  home.packages = with pkgs; [
    # Browser
    google-chrome

    # Editor
    vscode

    # Terminal
    kitty

    # App Launcher
    wofi

    # Status Bar
    waybar

    # File Manager
    thunar

    # Dev Tools
    python3
    gh           # GitHub CLI
    ripgrep
    fzf
    tmux
    neovim
    jq

    # Notifications
    dunst
    libnotify

    # Wallpaper
    swww

    # Screenshot
    grim
    slurp

    # Lock Screen
    swaylock

    # System tray
    blueman
  ];

  # ============================================================
  # HYPRLAND CONFIG
  # ============================================================
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = ",preferred,auto,1";

      exec-once = [
        "waybar"
        "swww init && swww img /run/current-system/sw/share/backgrounds/nixos/nix-wallpaper-simple-dark-gray.png"
        "dunst"
        "nm-applet --indicator"
        "blueman-applet"
      ];

      env = [
        "XCURSOR_SIZE,24"
        "GDK_BACKEND,wayland"
        "QT_QPA_PLATFORM,wayland"
      ];

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
        };
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
      };

      animations = {
        enabled = true;
      };

      # KEYBINDINGS
      "$mod" = "SUPER";

      bind = [
        "$mod, Return, exec, kitty"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, E, exec, thunar"
        "$mod, V, togglefloating"
        "$mod, R, exec, wofi --show drun"
        "$mod, F, fullscreen"

        # Move focus
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"

        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"

        # Screenshot
        ", Print, exec, grim -g \"$(slurp)\" ~/Pictures/screenshot.png"

        # Volume
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        # Brightness
        ", XF86MonBrightnessUp, exec, brightnessctl set 10%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # ============================================================
  # KITTY TERMINAL
  # ============================================================
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "FiraCode Nerd Font";
      font_size = 12;
      background_opacity = "0.95";
      confirm_os_window_close = 0;
    };
  };

  # ============================================================
  # GIT
  # ============================================================
  programs.git = {
    enable = true;
    userName = "AlMagrhibi";
    userEmail = "km@km-laptop";
  };

  # ============================================================
  # NEOVIM
  # ============================================================
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
  };

  programs.home-manager.enable = true;
}
