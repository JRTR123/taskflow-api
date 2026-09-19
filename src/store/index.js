// Picks the storage backend:
// - NODE_ENV === 'test' or no DATABASE_URL -> in-memory store (fast, no infra needed)
// - DATABASE_URL set (e.g. in Docker/staging/production) -> real PostgreSQL
const useMemory = process.env.NODE_ENV === 'test' || !process.env.DATABASE_URL;

module.exports = useMemory
  ? require('./memoryStore')
  : require('./pgStore');
