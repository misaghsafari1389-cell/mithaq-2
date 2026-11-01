// Reference scenarios for @playwright/test. Run against BASE_URL after publishing.
import { test, expect } from '@playwright/test';
const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:3000';

test('audio-only public form has the required fields', async ({ page }) => {
  await page.goto(`${BASE_URL}/`);
  await expect(page).toHaveTitle(/ثبت گزارش صوتی/);
  await expect(page.locator('#title')).toBeVisible();
  await expect(page.locator('#urgency')).toHaveValue('عادی');
  await expect(page.locator('#waveform')).toBeVisible();
  await expect(page.locator('#occurred-at')).toHaveCount(0);
  await expect(page.locator('#image-input')).toHaveCount(0);
});

test('audio is mandatory', async ({ page }) => {
  await page.goto(`${BASE_URL}/`);
  await page.locator('#title').fill('تست اعتبارسنجی');
  await page.locator('#submit-button').click();
  await expect(page.locator('[data-error-for="audio"]')).toHaveText('ضبط صدا برای ارسال الزامی است.');
});

test('admin route is direct access without login', async ({ page }) => {
  await page.goto(`${BASE_URL}/admin/`);
  await expect(page).toHaveTitle(/پنل مدیریت/);
  await expect(page.locator('#login-form')).toHaveCount(0);
  await expect(page.locator('#reports-list')).toBeVisible();
});
