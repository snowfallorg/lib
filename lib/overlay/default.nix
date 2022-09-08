{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (core-inputs.nixpkgs.lib) assertMsg;

  user-overlays-root = snowfall-lib.fs.get-file "overlays";
in
{
  overlay = {
    # Create a flake-utils-plus overlays builder.
    # Type: Attrs -> Attrs -> [(a -> b -> c)]
    # Usage: create-overlays { src = ./my-overlays; overlay-package-namespace = "my-packages"; }
    #   result: (channels: [ ... ])
    create-overlays =
      { src ? user-overlays-root
      , overlay-package-namespace ? null
      , extra-overlays ? [ ]
      }: channels:
      let
        user-overlays = snowfall-lib.fs.get-default-nix-files-recursive src;
        create-overlay = overlay: import overlay (user-inputs // { inherit channels; });
        user-packages-overlay = final: prev:
          let
            user-packages = snowfall-lib.package.create-packages {
              channels = channels;
            };
            user-packages-without-default = builtins.removeAttrs
              (user-packages) [ "default" ];
          in
          if overlay-package-namespace == null then
            user-packages-without-default
          else
            {
              ${overlay-package-namespace} = user-packages-without-default;
            };
        overlays = [ user-packages-overlay ] ++ extra-overlays ++ (builtins.map create-overlay user-overlays);
      in
      overlays;
  };
}
