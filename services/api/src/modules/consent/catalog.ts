/** Consent catalog. Wording is placeholder copy pending legal review (DPDP Act 2023). */
export const CONSENT_CATALOG = [
  {
    purpose: 'terms',
    version: '1.0',
    title: 'Terms of Service',
    description: 'I agree to the CareCompanion Terms of Service.',
    required: true,
    scope: 'platform',
  },
  {
    purpose: 'privacy',
    version: '1.0',
    title: 'Privacy Notice',
    description: 'I have read the Privacy Notice explaining how my data is collected, used and protected.',
    required: true,
    scope: 'platform',
  },
  {
    purpose: 'health_data_processing',
    version: '1.0',
    title: 'Health data processing',
    description: 'I consent to processing of my health information to coordinate my care.',
    required: true,
    scope: 'health_data',
  },
  {
    purpose: 'ai_assistance',
    version: '1.0',
    title: 'AI care assistant',
    description: 'I agree to use the AI assistant. It does not diagnose; it helps collect information and route me to care.',
    required: false,
    scope: 'ai',
  },
  {
    purpose: 'share_with_clinicians',
    version: '1.0',
    title: 'Share with my clinicians',
    description: 'Allow doctors and nurses treating me to view my relevant health records.',
    required: false,
    scope: 'clinical_sharing',
  },
  {
    purpose: 'family_sharing',
    version: '1.0',
    title: 'Family sharing',
    description: 'Allow family members I invite to access my information with the permissions I choose.',
    required: false,
    scope: 'family',
  },
  {
    purpose: 'marketing',
    version: '1.0',
    title: 'Offers and updates',
    description: 'Send me health tips, offers and product updates.',
    required: false,
    scope: 'marketing',
  },
] as const;

export const REQUIRED_CONSENTS: string[] = CONSENT_CATALOG.filter((c) => c.required).map((c) => c.purpose);
