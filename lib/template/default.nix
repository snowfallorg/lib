{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (builtins) baseNameOf;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl;

  user-templates-root = snowfall-lib.fs.get-file "templates";
in
{
  template = {
    # Create flake templates.
    # Type: Attrs -> Attrs
    # Usage: create-templates { src = ./my-templates; overrides = { inherit another-template; default = "my-template"; }; }
    #   result: { another-template = ...; my-template = ...; default = ...; }
    create-templates =
      { src ? user-templates-root
      , overrides ? { }
      }:
      let
        user-templates = snowfall-lib.fs.get-directories src;
        create-template-metadata = template: {
          name = builtins.unsafeDiscardStringContext (baseNameOf template);
          path = template;
        };
        templates-metadata = builtins.map create-template-metadata user-templates;
        merge-templates = templates: metadata:
          templates // {
            ${metadata.name} = (overrides.${metadata.name} or { }) // {
              inherit (metadata) path;
            };
          };
        templates-without-default = foldl merge-templates { } templates-metadata;
        default-template =
          if overrides.default or null == null then
            { }
          else if builtins.isAttrs overrides.default then
            { default = overrides.default; }
          else if templates-without-default.${overrides.default} or null != null then
            { default = templates-without-default.${overrides.default}; }
          else
            { };
        overrides-without-default = builtins.removeAttrs overrides [ "default" ];
        templates = templates-without-default // default-template // overrides-without-default;
      in
      templates;
  };
}
