{
  description = "Endless Sky";
  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" ];
    forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f { inherit system; pkgs = nixpkgs.legacyPackages.${system}; });
  in {
    packages = forEachSystem ({ system, pkgs }: {
      default = pkgs.stdenv.mkDerivation {
        pname = "endless-sky";
        version = "0.10.2";
        src = self;

        configurePhase = ''
          cmake --preset linux -DES_USE_VCPKG=OFF
        '';
        buildPhase = ''
          cmake --build --preset linux-release
        '';
        installPhase = ''
          mkdir -p $out/{share,bin}/ $out/share/applications
          cp -r $src $out/share/endless-sky
          substitute ${self}/endless-sky.desktop $out/share/applications/endless-sky.desktop \
            --replace Exec=endless-sky Exec=$out/bin/endless-sky \
            --replace Icon=endless-sky Icon=$src/icon.png
          cp build/linux/Release/endless-sky $out/bin/endless-sky
          wrapProgram $out/bin/endless-sky --add-flags "--resources $out/share/endless-sky"
        '';
        buildInputs = with pkgs; [
          SDL2
          libpng
          libjpeg
          mesa
          glew
          openal
          libmad
          libuuid
        ];
        nativeBuildInputs = with pkgs; [ cmake ninja git makeWrapper ];
      };
    });
    devShells = forEachSystem ({ system, pkgs }: {
      default = pkgs.mkShell {
        inputsFrom = [ self.packages.${system}.default ];
        packages = [
          pkgs.clang-tools # clangd
          (pkgs.writeShellScriptBin "es-reconfigure" ''
            rm -rf $SRC_DIR/build/
            cmake --preset linux -DES_USE_VCPKG=off
          '')
          (pkgs.writeShellScriptBin "es-build" ''
            cmake --build --preset linux-debug
          '')
          (pkgs.writeShellScriptBin "es-run" ''
            es-build && $SRC_DIR/build/linux/Debug/endless-sky "$@"
          '')
          (pkgs.writeShellScriptBin "es-test" ''
            es-build && ctest --preset linux-test
          '')
        ];
        shellHook = ''
          export SRC_DIR=$(git rev-parse --show-toplevel)
          es-reconfigure
        '';
      };
    });
  };
}
