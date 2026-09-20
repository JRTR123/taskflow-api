const { test, expect } = require('@playwright/test');

test('marks a task done', async ({ request }) => {
  const created = await request.post('/api/tasks', {
    data: { title: 'Mark me done in E2E' },
  });
  expect(created.ok()).toBeTruthy();
  const { id } = await created.json();

  const updated = await request.put(`/api/tasks/${id}`, {
    data: { status: 'done' },
  });
  expect(updated.ok()).toBeTruthy();
  const task = await updated.json();
  expect(task.status).toBe('done');
});
