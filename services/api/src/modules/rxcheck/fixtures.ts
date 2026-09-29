/**
 * FIXTURE INTERACTION PACK `interactions-fixture-0.1` — [REQUIRES CLINICAL GOVERNANCE — replace with a licensed drug
 * database adapter]. A small set of well-known, widely documented interaction pairs and drug classes so the software can
 * be exercised end to end. It is NOT complete and NOT a substitute for a licensed drug-interaction database.
 */
export const INTERACTION_PACK_VERSION = 'interactions-fixture-0.1';

export interface InteractionPair {
  a: string; // class:<name> or a drug name
  b: string;
  severity: 'info' | 'moderate' | 'major';
  message: string;
}

export interface InteractionPackContent {
  label: string;
  classes: Record<string, string[]>;
  /** Allergy class -> classes with possible cross-reactivity (moderate warning). */
  crossReactivity: Record<string, string[]>;
  pairs: InteractionPair[];
}

const G = '[FIXTURE — REQUIRES CLINICAL GOVERNANCE]';

export const INTERACTION_FIXTURE: InteractionPackContent = {
  label: `Fixture interaction pack ${G}`,
  classes: {
    penicillins: ['penicillin', 'amoxicillin', 'ampicillin', 'cloxacillin', 'flucloxacillin', 'piperacillin', 'co-amoxiclav', 'phenoxymethylpenicillin', 'benzathine penicillin'],
    cephalosporins: ['cefalexin', 'cephalexin', 'cefuroxime', 'ceftriaxone', 'cefixime', 'cefpodoxime', 'cefadroxil'],
    sulfonamides: ['sulfamethoxazole', 'cotrimoxazole', 'co-trimoxazole', 'sulfasalazine', 'sulfadiazine'],
    nsaids: ['ibuprofen', 'diclofenac', 'naproxen', 'aceclofenac', 'ketorolac', 'indomethacin', 'mefenamic acid', 'piroxicam', 'etoricoxib', 'celecoxib', 'nimesulide'],
    macrolides: ['azithromycin', 'clarithromycin', 'erythromycin'],
    fluoroquinolones: ['ciprofloxacin', 'levofloxacin', 'ofloxacin', 'moxifloxacin', 'norfloxacin'],
    statins: ['atorvastatin', 'rosuvastatin', 'simvastatin', 'pravastatin', 'lovastatin'],
    ace_inhibitors: ['enalapril', 'ramipril', 'lisinopril', 'perindopril', 'captopril'],
    arbs: ['losartan', 'telmisartan', 'olmesartan', 'valsartan', 'irbesartan'],
    potassium_sparing_diuretics: ['spironolactone', 'eplerenone', 'amiloride', 'triamterene'],
    potassium_supplements: ['potassium chloride', 'potassium citrate'],
    anticoagulants: ['warfarin', 'acenocoumarol', 'apixaban', 'rivaroxaban', 'dabigatran'],
    antiplatelets: ['aspirin', 'clopidogrel', 'prasugrel', 'ticagrelor'],
    nitrates: ['nitroglycerin', 'glyceryl trinitrate', 'isosorbide mononitrate', 'isosorbide dinitrate', 'nicorandil'],
    pde5_inhibitors: ['sildenafil', 'tadalafil', 'vardenafil'],
    ssris: ['fluoxetine', 'sertraline', 'escitalopram', 'citalopram', 'paroxetine', 'fluvoxamine'],
    maois: ['phenelzine', 'tranylcypromine', 'selegiline', 'rasagiline', 'linezolid'],
    opioids: ['tramadol', 'codeine', 'morphine', 'tapentadol', 'oxycodone', 'fentanyl'],
    benzodiazepines: ['alprazolam', 'clonazepam', 'diazepam', 'lorazepam', 'midazolam'],
    beta_blockers: ['metoprolol', 'atenolol', 'propranolol', 'bisoprolol', 'carvedilol', 'nebivolol'],
    non_dhp_ccbs: ['verapamil', 'diltiazem'],
    dhp_ccbs: ['amlodipine', 'nifedipine', 'cilnidipine', 'felodipine'],
    biguanides: ['metformin'],
    sulfonylureas: ['glimepiride', 'gliclazide', 'glibenclamide', 'glipizide'],
    iodinated_contrast: ['iodinated contrast', 'iohexol', 'iopamidol', 'iodixanol', 'contrast dye'],
    ppis: ['omeprazole', 'pantoprazole', 'esomeprazole', 'rabeprazole', 'lansoprazole'],
    azole_antifungals: ['fluconazole', 'ketoconazole', 'itraconazole', 'voriconazole'],
    corticosteroids: ['prednisolone', 'prednisone', 'dexamethasone', 'methylprednisolone', 'hydrocortisone'],
    analgesic_paracetamol: ['paracetamol', 'acetaminophen'],
  },
  crossReactivity: {
    penicillins: ['cephalosporins'],
  },
  pairs: [
    { a: 'warfarin', b: 'aspirin', severity: 'major', message: `Warfarin with aspirin: markedly increased bleeding risk. ${G}` },
    { a: 'class:anticoagulants', b: 'class:nsaids', severity: 'major', message: `Anticoagulant with an NSAID: increased bleeding risk. ${G}` },
    { a: 'class:anticoagulants', b: 'class:antiplatelets', severity: 'major', message: `Anticoagulant with an antiplatelet: increased bleeding risk; confirm this combination is intended. ${G}` },
    { a: 'clarithromycin', b: 'simvastatin', severity: 'major', message: `Clarithromycin with simvastatin: raised statin levels and risk of myopathy/rhabdomyolysis. ${G}` },
    { a: 'clarithromycin', b: 'lovastatin', severity: 'major', message: `Clarithromycin with lovastatin: risk of myopathy/rhabdomyolysis. ${G}` },
    { a: 'clarithromycin', b: 'atorvastatin', severity: 'moderate', message: `Clarithromycin with atorvastatin: raised statin levels; consider dose limits. ${G}` },
    { a: 'class:azole_antifungals', b: 'simvastatin', severity: 'major', message: `Azole antifungal with simvastatin: risk of myopathy/rhabdomyolysis. ${G}` },
    { a: 'class:nitrates', b: 'class:pde5_inhibitors', severity: 'major', message: `Nitrate with a PDE-5 inhibitor: risk of severe hypotension. ${G}` },
    { a: 'class:ace_inhibitors', b: 'class:potassium_sparing_diuretics', severity: 'major', message: `ACE inhibitor with a potassium-sparing diuretic: risk of hyperkalaemia; monitoring required. ${G}` },
    { a: 'class:arbs', b: 'class:potassium_sparing_diuretics', severity: 'major', message: `ARB with a potassium-sparing diuretic: risk of hyperkalaemia; monitoring required. ${G}` },
    { a: 'class:ace_inhibitors', b: 'class:potassium_supplements', severity: 'major', message: `ACE inhibitor with potassium supplements: risk of hyperkalaemia. ${G}` },
    { a: 'class:potassium_sparing_diuretics', b: 'class:potassium_supplements', severity: 'major', message: `Potassium-sparing diuretic with potassium supplements: risk of hyperkalaemia. ${G}` },
    { a: 'class:ace_inhibitors', b: 'class:arbs', severity: 'moderate', message: `ACE inhibitor with an ARB (dual RAAS blockade): kidney and potassium risks. ${G}` },
    { a: 'metformin', b: 'class:iodinated_contrast', severity: 'major', message: `Metformin with iodinated contrast: follow the local protocol for withholding metformin around contrast. ${G}` },
    { a: 'class:ssris', b: 'class:maois', severity: 'major', message: `SSRI with an MAO inhibitor: risk of serotonin syndrome. ${G}` },
    { a: 'tramadol', b: 'class:maois', severity: 'major', message: `Tramadol with an MAO inhibitor: risk of serotonin syndrome and seizures. ${G}` },
    { a: 'tramadol', b: 'class:ssris', severity: 'moderate', message: `Tramadol with an SSRI: risk of serotonin syndrome and lowered seizure threshold. ${G}` },
    { a: 'class:opioids', b: 'class:benzodiazepines', severity: 'major', message: `Opioid with a benzodiazepine: risk of profound sedation and respiratory depression. ${G}` },
    { a: 'methotrexate', b: 'class:nsaids', severity: 'major', message: `Methotrexate with an NSAID: risk of methotrexate toxicity. ${G}` },
    { a: 'lithium', b: 'class:nsaids', severity: 'major', message: `Lithium with an NSAID: raised lithium levels. ${G}` },
    { a: 'lithium', b: 'class:ace_inhibitors', severity: 'moderate', message: `Lithium with an ACE inhibitor: raised lithium levels; monitor. ${G}` },
    { a: 'warfarin', b: 'fluconazole', severity: 'major', message: `Warfarin with fluconazole: raised INR and bleeding risk. ${G}` },
    { a: 'warfarin', b: 'metronidazole', severity: 'major', message: `Warfarin with metronidazole: raised INR and bleeding risk. ${G}` },
    { a: 'warfarin', b: 'amiodarone', severity: 'major', message: `Warfarin with amiodarone: raised INR and bleeding risk. ${G}` },
    { a: 'warfarin', b: 'ciprofloxacin', severity: 'moderate', message: `Warfarin with ciprofloxacin: INR may rise; monitor. ${G}` },
    { a: 'warfarin', b: 'clarithromycin', severity: 'moderate', message: `Warfarin with clarithromycin: INR may rise; monitor. ${G}` },
    { a: 'warfarin', b: 'rifampicin', severity: 'moderate', message: `Warfarin with rifampicin: reduced anticoagulant effect. ${G}` },
    { a: 'amiodarone', b: 'simvastatin', severity: 'major', message: `Amiodarone with simvastatin: risk of myopathy; dose limits apply. ${G}` },
    { a: 'class:beta_blockers', b: 'class:non_dhp_ccbs', severity: 'major', message: `Beta-blocker with verapamil/diltiazem: risk of bradycardia and heart block. ${G}` },
    { a: 'allopurinol', b: 'azathioprine', severity: 'major', message: `Allopurinol with azathioprine: risk of bone-marrow toxicity. ${G}` },
    { a: 'carbamazepine', b: 'clarithromycin', severity: 'major', message: `Carbamazepine with clarithromycin: raised carbamazepine levels. ${G}` },
    { a: 'clopidogrel', b: 'omeprazole', severity: 'moderate', message: `Clopidogrel with omeprazole: may reduce clopidogrel effect. ${G}` },
    { a: 'simvastatin', b: 'amlodipine', severity: 'moderate', message: `Simvastatin with amlodipine: simvastatin dose limit applies. ${G}` },
    { a: 'simvastatin', b: 'class:non_dhp_ccbs', severity: 'moderate', message: `Simvastatin with verapamil/diltiazem: simvastatin dose limit applies. ${G}` },
    { a: 'digoxin', b: 'clarithromycin', severity: 'moderate', message: `Digoxin with clarithromycin: raised digoxin levels. ${G}` },
    { a: 'digoxin', b: 'verapamil', severity: 'moderate', message: `Digoxin with verapamil: raised digoxin levels and bradycardia. ${G}` },
    { a: 'class:nsaids', b: 'class:ace_inhibitors', severity: 'moderate', message: `NSAID with an ACE inhibitor: reduced BP control and kidney risk. ${G}` },
    { a: 'class:nsaids', b: 'class:corticosteroids', severity: 'moderate', message: `NSAID with a corticosteroid: increased GI bleeding risk. ${G}` },
    { a: 'class:antiplatelets', b: 'class:nsaids', severity: 'moderate', message: `Antiplatelet with an NSAID: increased GI bleeding risk. ${G}` },
    { a: 'class:ssris', b: 'class:nsaids', severity: 'moderate', message: `SSRI with an NSAID: increased bleeding risk. ${G}` },
    { a: 'class:ssris', b: 'class:anticoagulants', severity: 'moderate', message: `SSRI with an anticoagulant: increased bleeding risk. ${G}` },
    { a: 'class:fluoroquinolones', b: 'class:corticosteroids', severity: 'moderate', message: `Fluoroquinolone with a corticosteroid: risk of tendon damage. ${G}` },
    { a: 'ciprofloxacin', b: 'theophylline', severity: 'moderate', message: `Ciprofloxacin with theophylline: raised theophylline levels. ${G}` },
    { a: 'class:sulfonylureas', b: 'fluconazole', severity: 'moderate', message: `Sulfonylurea with fluconazole: risk of low blood sugar. ${G}` },
    { a: 'phenytoin', b: 'fluconazole', severity: 'moderate', message: `Phenytoin with fluconazole: raised phenytoin levels. ${G}` },
  ],
};
