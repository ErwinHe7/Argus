import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.axio7.app',
  appName: 'AXIO7',
  webDir: 'www',
  server: {
    url: 'https://axio7.com/housing?native=ios',
    cleartext: false,
    allowNavigation: [
      'axio7.com',
      '*.axio7.com',
      '*.supabase.co',
      'appleid.apple.com',
      'accounts.google.com'
    ]
  },
  ios: {
    contentInset: 'automatic'
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 800,
      backgroundColor: '#0A1520',
      showSpinner: false
    },
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#0A1520'
    },
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert']
    }
  }
};

export default config;
