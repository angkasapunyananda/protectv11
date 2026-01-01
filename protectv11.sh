
#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/StartupModificationService.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

echo "🚀 Memasang proteksi Startup Configuration (Admin ID 1 only)..."

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup dibuat: $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Models\Server;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class StartupModificationService
{
    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $repository
    ) {}

    public function handle(Server $server, array $data): Server
    {
        $user = Auth::user();

        if (!$user || $user->id !== 1) {
            throw new DisplayException(
                '🚫 AKSES DITOLAK: Hanya Admin Utama (ID 1) yang bisa edit Startup Configuration.'
            );
        }

        return $this->connection->transaction(function () use ($data, $server) {
            $server->startup = Arr::get($data, 'startup', $server->startup);
            $server->image = Arr::get($data, 'image', $server->image);
            $server->saveOrFail();

            $environment = Arr::get($data, 'environment', []);

            foreach ($environment as $key => $value) {
                $server->variables()->updateOrCreate(
                    ['variable' => $key],
                    ['variable_value' => $value]
                );
            }

            try {
                $this->repository->setServer($server)->sync();
            } catch (DaemonConnectionException $exception) {
            }

            return $server;
        });
    }
}
EOF

chmod 644 "$REMOTE_PATH"

echo "✅ Startup Configuration berhasil diproteksi!"
echo "🔒 Hanya Admin ID 1 yang bisa edit Startup"
echo "🗂️ Backup: $BACKUP_PATH"
