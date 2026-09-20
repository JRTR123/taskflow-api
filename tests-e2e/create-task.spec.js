const { test, expect } = require('@playwright/test');

test('creates a task', async ({ request }) => {
  const res = await request.post('/api/tasks', {
    data: { title: 'E2E created task' },
  });
  expect(res.status()).toBe(201);
  const task = await res.json();
  expect(task.title).toBe('E2E created task');
  expect(task.status).toBe('todo');
});
