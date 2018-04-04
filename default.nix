let
  localLib = import ./lib.nix;
in
{ system ? builtins.currentSystem
, config ? {}
, pkgs ? (import (localLib.fetchNixPkgs) { inherit system config; })
, cluster ? "mainnet"
, version ? "versionNotSet"
}:

let
  installPath = ".daedalus";
  cardanoPkgs = import ./cardano-sl.nix {
    inherit system config pkgs;
  };
  packages = self: {
    inherit cluster pkgs version;
    inherit (cardanoPkgs) daedalus-bridge;
    ## TODO: move to installers/nix
    daedalus-installer = self.callPackage ./installers/default.nix {};
    inherit (self.callPackage ./installers/nix/linux.nix {})
      daedalus daedalus-config;
    rawapp = self.callPackage ./yarn2nix.nix { api = "ada"; };
    nix-bundle = import (pkgs.fetchFromGitHub {
      owner = "matthewbauer";
      repo = "nix-bundle";
      rev = "630e89d1d16083";
      sha256 = "1s9vzlsfxd2ym8jzv2p64j6jlwr9cmir45mb12yzzjr4dc91xk8x";
    }) { nixpkgs = pkgs; };
    desktopItem = pkgs.makeDesktopItem {
      name = "Daedalus";
      exec = "INSERT_PATH_HERE";
      desktopName = "Daedalus";
      genericName = "Crypto-Currency Wallet";
      categories = "Application;Network;";
      icon = "INSERT_ICON_PATH_HERE";
    };
    iconPath = ./installers/icons/1024x1024.png;
    namespaceHelper = pkgs.writeScriptBin "namespaceHelper" ''
      #!/usr/bin/env bash

      set -ex

      cd ~/${installPath}/
      mkdir -p etc
      cat /etc/hosts > etc/hosts
      cat /etc/nsswitch.conf > etc/nsswitch.conf
      cat /etc/machine-id > etc/machine-id
      cat /etc/resolv.conf > etc/resolv.conf
      exec .${self.nix-bundle.nix-user-chroot}/bin/nix-user-chroot -n ./nix -c -m /home:/home -m /etc:/host-etc -m etc:/etc -p DISPLAY -p HOME -p XAUTHORITY -- /nix/var/nix/profiles/profile/bin/enter-phase2 daedalus
    '';
    postInstall = pkgs.writeScriptBin "post-install" ''
      #!${pkgs.stdenv.shell}

      set -ex


      test -z "$XDG_DATA_HOME" && { XDG_DATA_HOME="''${HOME}/.local/share"; }
      export DAEDALUS_DIR="''${XDG_DATA_HOME}/Daedalus/${cluster}"
      mkdir -pv $DAEDALUS_DIR/Logs/pub

      exec 2>&1 > $DAEDALUS_DIR/Logs/pub/post-install.log

      echo "in post-install hook"

      cp -f ${self.iconPath} $DAEDALUS_DIR/icon.png
      cp -Lf ${self.namespaceHelper}/bin/namespaceHelper $DAEDALUS_DIR/namespaceHelper
      mkdir -pv ~/.local/bin ~/bin ''${XDG_DATA_HOME}/applications
      cp -Lf ${self.namespaceHelper}/bin/namespaceHelper ~/.local/bin/daedalus
      cp -Lf ${self.namespaceHelper}/bin/namespaceHelper ~/bin/daedalus

      cat ${self.desktopItem}/share/applications/Daedalus.desktop | sed \
        -e "s+INSERT_PATH_HERE+''${DAEDALUS_DIR}/namespaceHelper+g" \
        -e "s+INSERT_ICON_PATH_HERE+''${DAEDALUS_DIR}/icon.png+g" \
        > "''${XDG_DATA_HOME}/applications/Daedalus.desktop"
    '';
    newBundle = (import ./installers/nix/nix-installer.nix {
      installationSlug = installPath;
      installedPackages = [ self.daedalus self.postInstall self.namespaceHelper ];
      postInstall = self.postInstall;
      nix-bundle = self.nix-bundle;
    }).installerBundle;
  };
in pkgs.lib.makeScope pkgs.newScope packages
