{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl;

  user-shells-root = snowfall-lib.fs.get-file "shells";
in
{
  shell = {
    # Create flake output packages.
    # Type: Attrs -> Attrs
    # Usage: create-shells { inherit channels; src = ./my-shells; overrides = { inherit another-shell; default = "my-shell"; }; }
    #   result: { another-shell = ...; my-shell = ...; default = ...; }
    create-shells =
      { channels
      , src ? user-shells-root
      , overrides ? { }
      }:
      let
        user-shells = snowfall-lib.fs.get-default-nix-files-recursive src;
        create-shell-metadata = shell:
          {
            name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory shell);
            drv = channels.nixpkgs.callPackage shell {
              lib = snowfall-lib.internal.system-lib;
            };
          };
        shells-metadata = builtins.map create-shell-metadata user-shells;
        merge-shells = shells: metadata:
          shells // {
            ${metadata.name} = metadata.drv;
          };
        shells-without-default = foldl merge-shells { } shells-metadata;
        default-shell =
          if overrides.default or null == null then
            { }
          else if builtins.isAttrs overrides.default then
            { default = overrides.default; }
          else if shells-without-default.${overrides.default} or null != null then
            { default = shells-without-default.${overrides.default}; }
          else
            { };
        overrides-without-default = builtins.removeAttrs overrides [ "default" ];
        shells = shells-without-default // default-shell // overrides-without-default;
      in
      shells;
  };
}
