{ pkgs
, python3
, poetry2nix
}:
let
  inherit (poetry2nix) overrides mkPoetryApplication mkPoetryEnv mkPoetryPackages;

  defaultPoetryArgs = {
    python = pkgs.python3;
    projectDir = ./.;

    #preferWheels = false;
    preferWheels = true;
    
    overrides = overrides.withDefaults (self: super: {
      ### package specific overrides go here...

      # 'preferWheel = true' overrides 
      zmq = super.zmq.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { buildInputs = buildInputs ++ [ super.setuptools ]; }
      );
      ninja = super.ninja.overridePythonAttrs (
        { buildInputs ? [], ... }:
        {
          buildInputs = buildInputs ++ [
            super.scikit-build
            super.setuptools
            super.setuptools-scm
          ];
        }
      );

      # 'preferWheel = false' overrides
      cmake = super.cmake.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { 
          #format = "pyproject";
          buildInputs = buildInputs ++ [
            super.scikit-build-core
            super.pyproject-metadata
            super.pathspec
          ];
        }
      );
      fsspec = super.fsspec.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { buildInputs = buildInputs ++ [ super.hatchling super.hatch-vcs ]; }
      );
      #hf-transfer = super.hf-transfer.overridePythonAttrs (
      #  { pname
      #  , version
      #  , src
      #  , nativeBuildInputs ? []
      #  , ... }:
      #  { 
      #    cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
      #      inherit src;
      #      name = "${pname}-${version}";
      #      #sha256 = pkgs.lib.fakeSha256;
      #      hash = "sha256-C0HtzJwV0y9Z/FG1wLFk1ia2H26OJ7asrxSqPOYOBk0=";
      #    };
      #    nativeBuildInputs = nativeBuildInputs ++ [
      #      pkgs.rustPlatform.cargoSetupHook
      #      pkgs.rustPlatform.maturinBuildHook
      #    ];
      #  }
      #);
      interegular = super.interegular.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { buildInputs = buildInputs ++ [ super.setuptools ]; }
      );
      lm-format-enforcer = super.lm-format-enforcer.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { buildInputs = buildInputs ++ [ pkgs.poetry super.poetry-core ]; }
      );
      nvidia-ml-py = super.nvidia-ml-py.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { buildInputs = buildInputs ++ [ super.setuptools ]; }
      );
      openai = super.openai.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { buildInputs = buildInputs ++ [ super.hatch-fancy-pypi-readme ]; }
      );
      
      # runtime overrides
      triton = super.triton.overridePythonAttrs (
        { buildInputs ? [], ... }:
        { buildInputs = buildInputs ++ [ super.setuptools ]; }
      );



    });
  };
in 
{
  poetryApplication = (mkPoetryApplication defaultPoetryArgs).overridePythonAttrs (
    { passthru ? {}, ... }:
    {
      passthru = passthru // {
        port = "8080";
      };
    }
  );
  poetryEnv = mkPoetryEnv (defaultPoetryArgs // {
    editablePackageSources.playground = ./.;
  });
}
