const express = require('express');
const store = require('../store');

const router = express.Router();

const VALID_STATUSES = ['todo', 'in-progress', 'done'];

router.get('/', async (req, res, next) => {
  try {
    const tasks = await store.listTasks();
    res.json(tasks);
  } catch (err) {
    next(err);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const task = await store.getTask(req.params.id);
    if (!task) return res.status(404).json({ error: 'Task not found' });
    return res.json(task);
  } catch (err) {
    return next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { title, description, status, priority } = req.body;
    if (!title || typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({ error: 'title is required' });
    }
    if (status && !VALID_STATUSES.includes(status)) {
      return res.status(400).json({ error: `status must be one of ${VALID_STATUSES.join(', ')}` });
    }
    const task = await store.createTask({ title, description, status, priority });
    return res.status(201).json(task);
  } catch (err) {
    return next(err);
  }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { title, description, status, priority } = req.body;
    if (status && !VALID_STATUSES.includes(status)) {
      return res.status(400).json({ error: `status must be one of ${VALID_STATUSES.join(', ')}` });
    }
    const updates = {};
    if (title !== undefined) updates.title = title;
    if (description !== undefined) updates.description = description;
    if (status !== undefined) updates.status = status;
    if (priority !== undefined) updates.priority = priority;

    const task = await store.updateTask(req.params.id, updates);
    if (!task) return res.status(404).json({ error: 'Task not found' });
    return res.json(task);
  } catch (err) {
    return next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const deleted = await store.deleteTask(req.params.id);
    if (!deleted) return res.status(404).json({ error: 'Task not found' });
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
