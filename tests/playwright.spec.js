// Reference scenarios for @playwright/test. Run against BASE_URL after publishing.
import { test, expect } from '@playwright/test';
const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:3000';

test('public form validates required fields', async ({ page }) => {
  await page.goto(`${BASE_URL}/`);
  await page.locator('#preview-button').click();
  await expect(page.locator('[data-error-for="title"]')).toHaveText('عنوان را وارد کنید.');
  await expect(page.locator('[data-error-for="description"]')).toHaveText('شرح واقعه باید حداقل ۱۰ نویسه باشد.');
});

test('admin route renders protected login', async ({ page }) => {
  await page.goto(`${BASE_URL}/admin/`);
  await expect(page).toHaveTitle(/پنل مدیریت/);
  await expect(page.locator('#login-form')).toBeVisible();
});
