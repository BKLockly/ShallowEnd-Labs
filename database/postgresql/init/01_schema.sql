-- shlabs_hr：HR 域（PostgreSQL 16）
-- 首次初始化由 docker-entrypoint 自动执行（以 POSTGRES_USER=shlabs 连接 shlabs_hr 库）；
-- 02_data.sql 为生成种子数据，勿手改

CREATE TABLE departments (
    id       SERIAL PRIMARY KEY,
    name     VARCHAR(64) NOT NULL UNIQUE,
    location VARCHAR(32) NOT NULL,
    budget_wan NUMERIC(10,1) NOT NULL
);

CREATE TABLE employees (
    id        SERIAL PRIMARY KEY,
    dept_id   INT NOT NULL REFERENCES departments(id),
    name      VARCHAR(32) NOT NULL,
    gender    VARCHAR(2) NOT NULL,
    hire_date DATE NOT NULL,
    email     VARCHAR(128) NOT NULL UNIQUE,
    phone     VARCHAR(16) NOT NULL,
    salary_k  INT NOT NULL,
    status    VARCHAR(16) NOT NULL DEFAULT 'active'
);
CREATE INDEX idx_employees_dept ON employees(dept_id);

CREATE TABLE salary_records (
    id          SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(id),
    pay_date    DATE NOT NULL,
    base_k      INT NOT NULL,
    bonus_k     INT NOT NULL DEFAULT 0,
    deduction_k INT NOT NULL DEFAULT 0
);
CREATE INDEX idx_salary_emp ON salary_records(employee_id);

CREATE TABLE attendance (
    id          SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(id),
    work_date   DATE NOT NULL,
    check_in    VARCHAR(8) NOT NULL,
    check_out   VARCHAR(8) NOT NULL,
    status      VARCHAR(8) NOT NULL DEFAULT 'normal'
);
CREATE INDEX idx_attendance_emp ON attendance(employee_id, work_date);

CREATE TABLE leave_requests (
    id          SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(id),
    leave_type  VARCHAR(16) NOT NULL,
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    reason      VARCHAR(255) NOT NULL,
    status      VARCHAR(8) NOT NULL DEFAULT 'pending',
    approver_id INT REFERENCES employees(id)
);

CREATE TABLE performance_reviews (
    id          SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES employees(id),
    reviewer_id INT NOT NULL REFERENCES employees(id),
    quarter     VARCHAR(8) NOT NULL,
    grade       VARCHAR(2) NOT NULL,
    comment     VARCHAR(255) NOT NULL
);
CREATE INDEX idx_perf_emp ON performance_reviews(employee_id);

CREATE TABLE projects (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(64) NOT NULL,
    dept_id    INT NOT NULL REFERENCES departments(id),
    start_date DATE NOT NULL,
    end_date   DATE NULL,
    budget_wan NUMERIC(10,1) NOT NULL
);

CREATE TABLE project_members (
    id          SERIAL PRIMARY KEY,
    project_id  INT NOT NULL REFERENCES projects(id),
    employee_id INT NOT NULL REFERENCES employees(id),
    role        VARCHAR(16) NOT NULL
);

CREATE TABLE job_postings (
    id           SERIAL PRIMARY KEY,
    dept_id      INT NOT NULL REFERENCES departments(id),
    title        VARCHAR(64) NOT NULL,
    headcount    INT NOT NULL DEFAULT 1,
    salary_min_k INT NOT NULL,
    salary_max_k INT NOT NULL,
    posted_at    DATE NOT NULL,
    closed       BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE candidates (
    id         SERIAL PRIMARY KEY,
    posting_id INT NOT NULL REFERENCES job_postings(id),
    name       VARCHAR(32) NOT NULL,
    channel    VARCHAR(32) NOT NULL,
    stage      VARCHAR(16) NOT NULL,
    created_at DATE NOT NULL
);

CREATE TABLE interviews (
    id             SERIAL PRIMARY KEY,
    candidate_id   INT NOT NULL REFERENCES candidates(id),
    interviewer_id INT NOT NULL REFERENCES employees(id),
    scheduled_at   TIMESTAMP NOT NULL,
    result         VARCHAR(8) NOT NULL DEFAULT 'pending'
);

CREATE TABLE assets (
    id          SERIAL PRIMARY KEY,
    employee_id INT REFERENCES employees(id),
    asset_type  VARCHAR(16) NOT NULL,
    serial_no   VARCHAR(32) NOT NULL UNIQUE,
    assigned_at DATE NOT NULL
);
