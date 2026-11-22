// lib/src/features/technician — the technician feature's PUBLIC API (barrel).
//
// The app shell and router import the technician feature ONLY from here. The
// backend HTTP details, secure token storage, and screen internals stay private
// to the feature; a real-vs-mock swap changes only the data layer.

export 'data/technician.dart' show Technician;
export 'data/technician_token_store.dart'
    show TechnicianTokenStore, technicianTokenStoreProvider;
export 'technician_session.dart'
    show
        TechnicianSessionController,
        technicianSessionProvider,
        TechnicianSessionX;
