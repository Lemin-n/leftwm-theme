{
  description = "leftwm theme control interface";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    fenix.url = "github:nix-community/fenix/monthly";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
  };
  outputs =
    inputs @ { flake-parts
    , fenix
    , nixpkgs
    , crane
    , ...
    }:
    inputs.flake-parts.lib.mkFlake
      {
        inherit inputs;
      }
      {
        systems = [ "x86_64-linux" ];
        perSystem =
          { config
          , pkgs
          , system
          , ...
          }:
          let
            lib = pkgs.lib;
            toolchain = fenix.packages.x86_64-linux.latest.toolchain;
            craneLib = (crane.lib.${system}.overrideToolchain toolchain).overrideScope' (final: prev: {
              mkCargoDerivation = args:
                prev.mkCargoDerivation ({
                  impureEnvVars =
                    lib.fetchers.proxyImpureEnvVars
                      ++ [
                      "GIT_PROXY_COMMAND"
                      "NIX_GIT_SSL_CAINFO"
                      "SOCKS_SERVER"
                    ];
                }
                // args);
            });
            src = craneLib.cleanCargoSource (craneLib.path ./.);
            commonArgs = {
              inherit src;
              pname = "leftwm-theme";
              nativeBuildInputs = with pkgs; [
                pkg-config
                openssl
                openssl.dev
                perl
                xorg.libX11
                xorg.libXinerama
              ];
              preConfigure = ''
                mkdir -p home/build
                export HOME=$(pwd)/home/build
                export XDG_CONFIG_HOME="$HOME/.config";
                export PKG_CONFIG_PATH=${pkgs.openssl.dev}/lib/pkgconfig
                export OPENSSL_DIR=${pkgs.openssl.dev}
              '';
            };
            cargoArtifacts =
              craneLib.buildDepsOnly commonArgs;
            app = craneLib.buildPackage (commonArgs
              // {
              inherit cargoArtifacts;
              doCheck = false;
            });
          in
          rec
          {
            packages.default = app;
          };
      };
}
