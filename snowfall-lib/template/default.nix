{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (builtins) baseNameOf;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl mapAttrs;

  user-templates-root = snowfall-lib.fs.get-snowfall-file "templates";
in {
  template = {
    ## Create flake templates.
    ##
    ## Example Usage:
    ## ```nix
    ## create-templates { src = ./my-templates; overrides = { inherit another-template; }; alias = { default = "another-template"; }; }
    ## ```
    ##
    ## Result:
    ## ```nix
    ## { another-template = ...; my-template = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-templates = {
      src ? user-templates-root,
      overrides ? {},
      alias ? {},
    }: let
      user-templates = snowfall-lib.fs.get-directories src;
      create-template-metadata = template: {
        name = builtins.unsafeDiscardStringContext (baseNameOf template);
        path = template;
      };
      templates-metadata = builtins.map create-template-metadata user-templates;
      merge-templates = templates: metadata:
        templates
        // {
          ${metadata.name} =
            (overrides.${metadata.name} or {})
            // {
              inherit (metadata) path;
            };
        };
      templates-without-aliases = foldl merge-templates {} templates-metadata;
      aliased-templates = mapAttrs (name: value: templates-without-aliases.${value}) alias;
      unused-overrides = builtins.removeAttrs overrides (builtins.map (metadata: metadata.name) templates-metadata);
      templates = templates-without-aliases // aliased-templates // unused-overrides;
    in
      templates;
  };
}
