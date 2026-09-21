process.env.NODE_ENV = 'test';
const request = require('supertest');
const app = require('../src/app');
const memoryStore = require('../src/store/memoryStore');

beforeEach(() => {
  memoryStore.reset();
});

describe('GET /health', () => {
  it('returns 200 and status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('Task CRUD', () => {
  it('lists tasks (empty at first)', async () => {
    const res = await request(app).get('/api/tasks');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('creates a task', async () => {
    const res = await request(app)
      .post('/api/tasks')
      .send({ title: 'Write pipeline report' });
    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Write pipeline report');
    expect(res.body.status).toBe('todo');
    expect(res.body.priority).toBe('normal');
  });

  it('creates a task with priority', async () => {
    const res = await request(app)
      .post('/api/tasks')
      .send({ title: 'Urgent item', priority: 'high' });
    expect(res.status).toBe(201);
    expect(res.body.priority).toBe('high');
  });

  it('rejects creating a task without a title', async () => {
    const res = await request(app).post('/api/tasks').send({});
    expect(res.status).toBe(400);
  });

  it('gets a single task by id', async () => {
    const created = await request(app)
      .post('/api/tasks')
      .send({ title: 'Fetch me' });
    const res = await request(app).get(`/api/tasks/${created.body.id}`);
    expect(res.status).toBe(200);
    expect(res.body.title).toBe('Fetch me');
  });

  it('returns 404 for a missing task', async () => {
    const res = await request(app).get('/api/tasks/9999');
    expect(res.status).toBe(404);
  });

  it('marks a task done', async () => {
    const created = await request(app)
      .post('/api/tasks')
      .send({ title: 'Mark me done' });
    const res = await request(app)
      .put(`/api/tasks/${created.body.id}`)
      .send({ status: 'done' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('done');
  });

  it('deletes a task', async () => {
    const created = await request(app)
      .post('/api/tasks')
      .send({ title: 'Delete me' });
    const res = await request(app).delete(`/api/tasks/${created.body.id}`);
    expect(res.status).toBe(204);

    const check = await request(app).get(`/api/tasks/${created.body.id}`);
    expect(check.status).toBe(404);
  });
});
