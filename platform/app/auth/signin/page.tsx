import { redirect } from 'next/navigation';

export default function LegacySignInPage() {
  redirect('/app/#/sign-in');
}
