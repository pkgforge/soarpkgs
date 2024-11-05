##AVOID!!! https://github.com/nix-community/nixGL/issues/25

##This uses https://github.com/nix-community/nixGL
#This is an workaround for: https://github.com/NixOS/nixpkgs/issues/9415
#More Details: https://github.com/Azathothas/Toolpacks-Extras/blob/main/Docs/NIXAPPIMAGES.md
#Self: curl -qfsSL "https://raw.githubusercontent.com/Azathothas/Toolpacks-Extras/refs/heads/main/.github/assets/nix-flakes/nix-community_nixGL.nix" -o "./flake.nix"

#Sed replaces the PKG_NAME with ${APP} & PKG_ARCH with "$(uname -m)"
{
  description = "Local build of PKG_NAME with nixGL overlay";
  inputs = {
    #Uses locally cloned Repo (Latest from Master: https://github.com/NixOS/nixpkgs)
    nixpkgs.url = "path:/opt/nixpkgs";
    #https://github.com/nix-community/nixGL#use-an-overlay
    nixgl.url = "github:nix-community/nixGL";
  };

  outputs = { self, nixpkgs, nixgl }:
    let
      #PKG_ARCH is auto replaced with $(uname -m)
      system = "PKG_ARCH-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nixgl.overlays.default ];
      };
    in {
      #PKG_NAME is auto replaced with ${APP}
      packages.${system}.default = pkgs.PKG_NAME;
      #Allows using, nix develop for debugging
      devShells.${system}.default = pkgs.mkShell {
        #PKG_NAME is auto replaced with ${APP}
        buildInputs = [ pkgs.PKG_NAME ];
      };
    };
}
##END