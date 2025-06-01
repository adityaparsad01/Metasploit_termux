#!/data/data/com.termux/files/usr/bin/bash

# Remove Old Folder if exist
find "$HOME" -name "metasploit-*" -type d -exec rm -rf {} \;

cwd=$(pwd)
msfvar=6.1.21 # The specific Metasploit version
msfpath='/data/data/com.termux/files/home'
msf_install_dir="$msfpath/metasploit-framework"

echo "[*] Updating and upgrading Termux packages..."
apt update -y && apt upgrade -y

echo "[*] Installing essential build tools and libraries..."
apt install -y binutils libiconv zlib autoconf bison clang coreutils curl findutils git apr apr-util libffi libgmp libpcap postgresql readline libsqlite openssl libtool libxml2 libxslt ncurses pkg-config wget make ruby libgrpc termux-tools ncurses-utils ncurses unzip zip tar termux-elf-cleaner

# Many phones are claiming libxml2 not found error, create a symlink if missing
if [ ! -L "$PREFIX/include/libxml2/libxml" ] && [ -d "$PREFIX/include/libxml2" ]; then
    echo "[*] Creating libxml2 symlink for compatibility..."
    ln -sf "$PREFIX/include/libxml2/libxml" "$PREFIX/include/"
fi

echo "[*] Downloading Metasploit Framework version ${msfvar}..."
cd "$msfpath" || exit 1
curl -LO "https://github.com/rapid7/metasploit-framework/archive/refs/tags/${msfvar}.tar.gz"

echo "[*] Extracting Metasploit Framework..."
tar -xf "${msfpath}/${msfvar}.tar.gz"
mv "${msfpath}/metasploit-framework-${msfvar}" "${msf_install_dir}"
cd "${msf_install_dir}" || exit 1

echo "[*] Patching Metasploit Framework files for Ruby 3.4+ compatibility..."

# Patch metasploit-framework.gemspec for dependency versions and missing gems
# Allows newer nokogiri, packetfu, pcaprub, and adds explicit standard library gems
sed -i 's/^  spec.add_runtime_dependency \x27nokogiri\x27, \x27~> 1.12\x27$/  spec.add_runtime_dependency \x27nokogiri\x27, \x27~> 1.18\x27/' "${msf_install_dir}/metasploit-framework.gemspec"
sed -i 's/^  spec.add_runtime_dependency \x27packetfu\x27, \x27~> 1.1\x27$/  spec.add_runtime_dependency \x27packetfu\x27, \x27~> 1.5\x27/' "${msf_install_dir}/metasploit-framework.gemspec"
sed -i 's/^  spec.add_runtime_dependency \x27pcaprub\x27, \x270.12.4\x27$/  spec.add_runtime_dependency \x27pcaprub\x27, \x27~> 0.13.1\x27/' "${msf_install_dir}/metasploit-framework.gemspec"

# Add missing standard library gems to gemspec
# The 'a' command appends after the matched line. Using a line that should exist.
sed -i '/spec.add_runtime_dependency \x27pcaprub\x27, \x27~> 0.13.1\x27/a\
  spec.add_runtime_dependency \x27abbrev\x27\n\
  spec.add_runtime_dependency \x27benchmark\x27\n\
  spec.add_runtime_dependency \x27net-smtp\x27\n\
  spec.add_runtime_dependency \x27ostruct\x27\n\
  spec.add_runtime_dependency \x27syslog\x27' "${msf_install_dir}/metasploit-framework.gemspec"


# Patch lib/net/dns/rr.rb for Regexp.new ArgumentError
# Old: Regexp.new("...", Regexp::IGNORECASE, "n")
# New: Regexp.new("...", Regexp::IGNORECASE)
sed -i 's/, "n")//' "${msf_install_dir}/lib/net/dns/rr.rb"


# Patch msfdb for Psych::AliasesNotEnabled (YAML.load)
# Old: config = YAML.load(File.read(@db_conf))
# New: config = YAML.load(File.read(@db_conf), aliases: true)
sed -i 's/config = YAML.load(File.read(@db_conf))/config = YAML.load(File.read(@db_conf), aliases: true)/' "${msf_install_dir}/msfdb"


# Patch lib/msf/core/db_manager.rb for Psych::AliasesNotEnabled (YAML.load_file)
# Old: dbinfo = YAML.load_file(configuration_pathname) || {}
# New: dbinfo = YAML.load_file(configuration_pathname, aliases: true) || {}
sed -i 's/dbinfo = YAML.load_file(configuration_pathname) || {}/dbinfo = YAML.load_file(configuration_pathname, aliases: true) || {}/' "${msf_install_dir}/lib/msf/core/db_manager.rb"


# Install bundler (ensure it's present and correct version)
echo "[*] Installing Bundler..."
gem install bundler --no-document || { echo "[-] Bundler installation failed."; exit 1; }

echo "[*] Installing all Metasploit Framework gems. This may take a while..."
# bundle config build.nokogiri --use-system-libraries is not needed if using newer nokogiri versions
# gem install nokogiri -v 1.12.5 -- --use-system-libraries is removed as gemspec handles it now
bundle install || { echo "[-] Gem installation failed. Check network and storage."; exit 1; }
echo "[*] All Metasploit Framework gems installed successfully."

# Some fixes for Termux environment
echo "[*] Applying Termux-specific fixes..."
sed -i "s@/etc/resolv.conf@$PREFIX/etc/resolv.conf@g" "${msf_install_dir}/lib/net/dns/resolver.rb"
find "${msf_install_dir}" -type f -executable -print0 | xargs -0 -r termux-fix-shebang
find "${PREFIX}/lib/ruby/gems" -type f -iname \*.so -print0 | xargs -0 -r termux-elf-cleaner

echo "[*] Creating database configuration file..."
mkdir -p "${msf_install_dir}/config" && cd "${msf_install_dir}/config" || exit 1
curl -LO https://raw.githubusercontent.com/Hax4us/Metasploit_termux/master/database.yml

echo "[*] Setting up PostgreSQL database for Metasploit..."
mkdir -p "$PREFIX/var/lib/postgresql"
pg_ctl -D "$PREFIX"/var/lib/postgresql stop > /dev/null 2>&1 || true

# Initialize PostgreSQL if not already initialized
if ! pg_ctl -D "$PREFIX"/var/lib/postgresql start --silent; then
    echo "[*] Initializing PostgreSQL database..."
    initdb "$PREFIX"/var/lib/postgresql || { echo "[-] PostgreSQL initialization failed."; exit 1; }
    pg_ctl -D "$PREFIX"/var/lib/postgresql start --silent || { echo "[-] PostgreSQL start failed after init."; exit 1; }
fi

# Create msf user and database if they don't exist
if [ -z "$(psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='msf'")" ]; then
    echo "[*] Creating PostgreSQL user 'msf'..."
    createuser msf || { echo "[-] Failed to create user 'msf'."; exit 1; }
fi
if [ -z "$(psql -l | grep msf_database)" ]; then
    echo "[*] Creating PostgreSQL database 'msf_database'..."
    createdb msf_database || { echo "[-] Failed to create database 'msf_database'."; exit 1; }
fi

echo "[*] Cleaning up downloaded archive..."
rm "${msfpath}/${msfvar}.tar.gz"

echo "[*] Setting up msfconsole and msfvenom symlinks..."
cd "${PREFIX}/bin" || exit 1
curl -LO https://raw.githubusercontent.com/Hax4us/Metasploit_termux/master/msfconsole || { echo "[-] Failed to download msfconsole symlink."; exit 1; }
chmod +x msfconsole
ln -sf "$(which msfconsole)" "$PREFIX/bin/msfvenom"

echo ""
echo "[*] Metasploit Framework installation and setup complete!"
echo "[*] Now, you need to initialize the Metasploit database schema."
echo "[*] Run the following command:"
echo "    cd ${msf_install_dir} && ./msfdb init"
echo "[*] When prompted to delete existing data and configurations, type 'yes'."
echo "[*] After successful database initialization, you can launch Metasploit."
echo "[*] To start Metasploit, run: msfconsole"
echo "[*] Remember to start PostgreSQL (msfdb start) before msfconsole."
echo ""
echo "You can directly use msfvenom or msfconsole rather than ./msfvenom or ./msfconsole."
