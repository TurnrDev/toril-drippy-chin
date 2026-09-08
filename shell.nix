{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    gdal
    git
    git-lfs
    nginx
  ];

  shellHook = ''
    echo "Toril imagery environment"
    echo "GDAL: $(gdalinfo --version)"
    echo "Git:  $(git --version)"
    echo
    echo "Build tiles with:"
    echo "  ./scripts/build-tiles.sh"
  '';
}

