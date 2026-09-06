Installation of the application is now complete. First thing you should do is **configure the email sending for your server**. If you use SMTP, you can use the app configuration panel within the YunoHost admin interface. You can also check other possibilities in the documentation available in the upstream loops-server repo (https://github.com/joinloops/loops-server/blob/main/INSTALLATION.md#mail-configuration).

When running Yunohost 13+ (Trixie) the install script **installs the RedisBloom module globally on the system** to enable the "For You" feed feature. The RedisBloom module **has to be enabled manually by you** by going to /etc/redis/redis.conf and removing the # before the *loadmodule /etc/redis/modules/redisbloom.so* line. Then restart Redis *(sudo systemctl restart redis)*.

When installing Loops on Yunohost 12 (Bookworm) or if you decide against enabling the RedisBloom module the server still works except for the "For You" feature. 

To remove RedisBloom from the system, go to /etc/redis/modules and remove the redisbloom.so module. Also remove the line "loadmodule /etc/redis/modules/redisbloom.so" from /etc/redis/redis.conf. Then restart Redis. 
