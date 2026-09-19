const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function listTasks() {
  const { rows } = await pool.query(
    'SELECT * FROM tasks ORDER BY id ASC',
  );
  return rows;
}

async function getTask(id) {
  const { rows } = await pool.query(
    'SELECT * FROM tasks WHERE id = $1',
    [id],
  );
  return rows[0] || null;
}

async function createTask({ title, description = '', status = 'todo' }) {
  const { rows } = await pool.query(
    `INSERT INTO tasks (title, description, status)
     VALUES ($1, $2, $3) RETURNING *`,
    [title, description, status],
  );
  return rows[0];
}

async function updateTask(id, updates) {
  const existing = await getTask(id);
  if (!existing) return null;
  const merged = { ...existing, ...updates };
  const { rows } = await pool.query(
    `UPDATE tasks SET title = $1, description = $2, status = $3
     WHERE id = $4 RETURNING *`,
    [merged.title, merged.description, merged.status, id],
  );
  return rows[0];
}

async function deleteTask(id) {
  const { rowCount } = await pool.query(
    'DELETE FROM tasks WHERE id = $1',
    [id],
  );
  return rowCount > 0;
}

module.exports = {
  listTasks,
  getTask,
  createTask,
  updateTask,
  deleteTask,
  pool,
};
