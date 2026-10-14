import assert from 'node:assert/strict';
import { test } from 'node:test';
import { planFills, type FormField } from '../src/answers.ts';

const fields: FormField[] = [
  { id: 'f0', type: 'text', label: 'Full name *', required: true, options: [] },
  { id: 'g1', type: 'radio', label: 'Authorized to work in the US? *', required: true, options: ['Yes', 'No'] },
  { id: 'f2', type: 'select', label: 'Gender', required: false, options: ['Female', 'Male', 'Decline to self-identify'] },
  { id: 'g3', type: 'checkbox-group', label: 'Offices', required: false, options: ['New York', 'Remote'] },
  { id: 'f4', type: 'checkbox', label: 'I acknowledge the privacy notice *', required: true, options: [] },
  { id: 'f5', type: 'file', label: 'Resume/CV *', required: true, options: [] },
  { id: 'f6', type: 'combobox', label: 'City', required: false, options: [] },
];

test('keeps answers that match the form and normalizes option spelling', () => {
  const { fills, missing } = planFills(fields, [
    { id: 'f0', values: [' Jane Doe '], note: '' },
    { id: 'g1', values: ['yes', 'No'], note: '' },
    { id: 'f2', values: ['decline to self-identify'], note: '' },
    { id: 'g3', values: ['Remote', 'Mars', 'New York'], note: '' },
    { id: 'f4', values: ['Yes'], note: '' },
    { id: 'f6', values: ['Brooklyn, NY'], note: '' },
  ]);
  assert.deepEqual(missing, []);
  assert.deepEqual(fills, [
    { id: 'f0', type: 'text', values: ['Jane Doe'] },
    { id: 'g1', type: 'radio', values: ['Yes'] },
    { id: 'f2', type: 'select', values: ['Decline to self-identify'] },
    { id: 'g3', type: 'checkbox-group', values: ['Remote', 'New York'] },
    { id: 'f4', type: 'checkbox', values: ['Yes'] },
    { id: 'f6', type: 'combobox', values: ['Brooklyn, NY'] },
  ]);
});

test('invented options and unanswered required fields block submission', () => {
  const { fills, missing } = planFills(fields, [
    { id: 'f0', values: ['Jane Doe'], note: '' },
    { id: 'g1', values: ['Maybe'], note: 'Tell me your work authorization.' },
    { id: 'f4', values: [], note: '' },
    { id: 'unknown', values: ['x'], note: '' },
  ]);
  assert.deepEqual(fills.map(f => f.id), ['f0']);
  assert.deepEqual(missing, [
    { label: 'Authorized to work in the US? *', note: 'Tell me your work authorization.' },
    { label: 'I acknowledge the privacy notice *', note: 'No answer from your profile.' },
  ]);
});
