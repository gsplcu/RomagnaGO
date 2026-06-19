/// Configurazione bucket Firebase Storage per i JSON start_content.
library;

/// Bucket Firebase del progetto `romagnago-app`.
const kStartContentStorageBucket = 'romagnago-app.firebasestorage.app';

/// Prefisso oggetti (deve coincidere con [kStartContentRemoteJsonUrlTemplate]).
const kStartContentStoragePrefix = 'start_content';

/// Directory locale con manifest + JSON.
const kStartContentLocalDir = 'assets/data/start_content';

String get kStartContentGcsUri =>
    'gs://$kStartContentStorageBucket/$kStartContentStoragePrefix/';
