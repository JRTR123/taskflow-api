const { test, expect } = require('@playwright/test');

test('lists tasks', async ({ request }) => {
  const res = await request.get('/api/tasks');
  expect(res.ok()).toBeTruthy();
  const tasks = await res.json();
  expect(Array.isArray(tasks)).toBe(true);
});
