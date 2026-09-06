#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

timezone=$(timedatectl show --value --property=Timezone)

version_control() {
  which_version=$(yunohost --version) # Get version number 
  # ynh_print_info "Installed version of Yunohost: $which_version"
  yunoversion=$(echo "$which_version" | awk '/^yunohost:/{found=1} found && /version:/{print $2; exit}')
  if echo "$yunoversion" | grep -q "^13\."; then # Check if Version 13 is installed (required for redisbloom module is Redis 8.0)
    return 0 # Yes, it's YunoHost 13.x --> 0
  fi 
  return 1 # No, it's not --> 1
}
#=================================================
# REDISBLOOM INSTALLER
#=================================================

redisbloom_check_for_install() {
  check_bfmodule="$(redis-cli MODULE LIST)"
  redis_version="$(redis-server --version | sed -n 's/.*v=\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')"
  if echo "$check_bfmodule" | grep -qx "bf"; then
    ynh_print_info "RedisBloom module already installed. Skipping installation"
  elif [[ "$redis_version" =~ ^8\.0\.[0-9]+$ ]]; then
    ynh_print_info "Redis Server Version $redis_version detected. RedisBloom module installation starting."
    redisbloom_installer
  else
    ynh_print_info "Wrong Redis Server Version $redis_version detected. Please check the RedisBloom github to install the module for your Redis Version."
  fi
}

redisbloom_installer() {
    ynh_print_info "Installing RedisBloom module for Redis 8.0"

    # Stop Redis before modifying modules
    ynh_systemctl --service=redis --action=stop

    # Create a temporary working directory
    TMPDIR=$(mktemp -d)

    ynh_setup_source --dest_dir="$TMPDIR" --source_id="redisbloom"
    ynh_setup_source --dest_dir="$TMPDIR/deps/RedisModulesSDK" --source_id="redissdk"
    ynh_setup_source --dest_dir="$TMPDIR/deps/readies" --source_id="redisreadies"
    ynh_setup_source --dest_dir="$TMPDIR/deps/t-digest-c" --source_id="redistdigestc"
    ynh_setup_source --dest_dir="$TMPDIR/deps/t-digest-c/tests/vendor/google/benchmark" --source_id="googlebenchmark"
    
    pushd "$TMPDIR"

        # Build the module
        ynh_print_info "Building RedisBloom…"
        make

        # Detect the compiled .so file (architecture‑independent)
        SOFILE="$(find bin -name redisbloom.so | head -n 1)"

        # Fail‑safe: abort if not found
        if [[ -z "$SOFILE" ]]; then
            popd
            ynh_safe_rm "$TMPDIR"
            ynh_die "RedisBloom build failed. ERROR: redisbloom.so not found after build. Aborting installation."
        fi

        # Install module
        ynh_print_info "Installing module into /etc/redis/modules/"
        mkdir -p /etc/redis/modules
        cp "$SOFILE" /etc/redis/modules/redisbloom.so

    popd

    # Fix permissions (Redis 8.0 requires +x)
    chmod 755 /etc/redis/modules/redisbloom.so
    chown redis:redis /etc/redis/modules/redisbloom.so
    chmod +x /etc/redis/modules/redisbloom.so

    # Add loadmodule line to redis.conf if not already present
    if ! grep -q "^[[:space:]]*loadmodule /etc/redis/modules/redisbloom.so" /etc/redis/redis.conf; then
        ynh_print_info "Adding RedisBloom module to redis.conf without enabling it (has to be done manually)"
        echo "#loadmodule /etc/redis/modules/redisbloom.so" >> /etc/redis/redis.conf
    else
        ynh_print_info "RedisBloom module already present in redis.conf"
    fi

    # Cleanup
    ynh_safe_rm "$TMPDIR"

    ynh_print_info "RedisBloom installation completed successfully."
}

