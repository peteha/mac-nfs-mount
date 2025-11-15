class NfsMount < Formula
  desc "NFS mount manager for macOS with YAML configuration and automation support"
  homepage "https://github.com/peteha/mac-nfs-mount"
  url "https://github.com/peteha/mac-nfs-mount/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "812024ce9db7b48873039963013bbbcc82b749b5cc59fc31fff6df2cca1401f0"
  version "1.1.0"
  license "MIT"
  head "https://github.com/peteha/mac-nfs-mount.git", branch: "main"

  depends_on "yq"

  def install
    bin.install "nfs-mount.sh" => "nfs-mount"
    bin.install "setup-sudo.sh"
    
    # Install documentation
    doc.install "README.md"
    doc.install "QUICKSTART.md"
    doc.install "KEYBOARD_MAESTRO_SETUP.md"
    doc.install "CONFIG_REFERENCE.md"
    doc.install "example.yaml"
    
    # Create config directory on first install
    (var/"nfs-mount").mkpath
  end

  def post_install
    config_dir = Pathname.new(ENV["HOME"])/"/.config/nfs-mount"
    config_file = config_dir/"config.yaml"
    
    # Create config directory if it doesn't exist
    config_dir.mkpath unless config_dir.exist?
    
    # Don't overwrite existing config
    unless config_file.exist?
      ohai "Creating default configuration at #{config_file}"
      ohai "Please edit this file with your NFS server details"
      ohai "See example at: #{doc}/example.yaml"
      
      # Create default config
      (config_dir/"config.yaml").write <<~EOS
        # NFS Mount Configuration
        # Edit this file with your NFS server details
        # See #{doc}/example.yaml for examples

        # Global settings
        settings:
          base_mount_dir: "${HOME}/External"
          max_retries: 3
          retry_delay: 2
          
          mount_options:
            use_resvport: true
            nfsv3_extra_opts: ""
            nfsv4_extra_opts: ""

        # NFS mounts - replace with your actual mounts
        mounts:
          - server: "your-nas-server.local"
            share: "/mnt/tank/share"
            nfs_version: "3"
            mount_name: "nas-share"
            enabled: false
      EOS
    end
  end

  def caveats
    <<~EOS
      NFS Mount Manager has been installed!
      
      Configuration file: #{ENV["HOME"]}/.config/nfs-mount/config.yaml
      Documentation: #{doc}
      
      Next steps:
      1. Edit your configuration:
         nano ~/.config/nfs-mount/config.yaml
      
      2. Set up passwordless sudo (required for automation):
         setup-sudo.sh
      
      3. Mount your NFS shares:
         nfs-mount
      
      For Keyboard Maestro automation, use:
         nfs-mount --silent
      
      See the documentation for more details:
         #{doc}/QUICKSTART.md
    EOS
  end

  test do
    assert_match "NFS Mount Manager for macOS", shell_output("#{bin}/nfs-mount --help")
  end
end

