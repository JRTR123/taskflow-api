let tasks = [];
let nextId = 1;

function reset() {
  tasks = [];
  nextId = 1;
}

async function listTasks() {
  return tasks;
}

async function getTask(id) {
  return tasks.find((t) => t.id === Number(id)) || null;
}

async function createTask({ title, description = '', status = 'todo', priority = 'normal' }) {
  const task = {
    id: nextId++,
    title,
    description,
    status,
    priority,
    created_at: new Date().toISOString(),
  };
  tasks.push(task);
  return task;
}

async function updateTask(id, updates) {
  const task = await getTask(id);
  if (!task) return null;
  Object.assign(task, updates);
  return task;
}

async function deleteTask(id) {
  const before = tasks.length;
  tasks = tasks.filter((t) => t.id !== Number(id));
  return tasks.length < before;
}

module.exports = {
  listTasks,
  getTask,
  createTask,
  updateTask,
  deleteTask,
  reset,
};
