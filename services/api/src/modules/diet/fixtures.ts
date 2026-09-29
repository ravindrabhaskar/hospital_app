/**
 * FIXTURE DIET TEMPLATES `diet-fixture-0.1` — [REQUIRES CLINICAL GOVERNANCE: to be reviewed by a registered dietitian].
 * Simple Indian vegetarian / non-vegetarian meal ideas; portions and targets must be individualised by the clinician.
 */
export const DIET_CONTENT_VERSION = 'diet-fixture-0.1';

export const DIET_TEMPLATES = [
  {
    code: 'diabetic',
    name: 'Diabetes-friendly (Indian)',
    conditions: ['type 2 diabetes', 'prediabetes'],
    calorieTarget: 1600,
    meals: [
      { slot: 'early_morning', items: ['Warm water or unsweetened tea', 'A few soaked almonds (4-5)'] },
      { slot: 'breakfast', items: ['Vegetable oats upma or moong dal chilla', 'Or: 2 egg-white omelette with 1 multigrain roti'] },
      { slot: 'mid_morning', items: ['1 small guava or apple', 'Buttermilk (no sugar)'] },
      { slot: 'lunch', items: ['2 phulkas (whole wheat / jowar)', 'Dal, mixed vegetable sabzi, salad', 'Or: grilled fish / chicken curry (less oil) with vegetables'] },
      { slot: 'evening', items: ['Roasted chana or sprouts chaat', 'Green tea'] },
      { slot: 'dinner', items: ['1-2 phulkas or brown rice (small cup)', 'Palak paneer (low fat) or dal', 'Or: egg curry with vegetables'] },
      { slot: 'bedtime', items: ['Warm milk without sugar (small cup), if advised'] },
    ],
    avoid: ['Sugar, sweets, jaggery and honey', 'Sweetened drinks and fruit juices', 'Maida (white flour) products', 'Deep-fried snacks'],
    notes: 'Spread carbohydrates across meals; do not skip meals if you take diabetes medicines. [REQUIRES CLINICAL GOVERNANCE]',
  },
  {
    code: 'low_salt_cardiac',
    name: 'Low-salt, heart-healthy (Indian)',
    conditions: ['hypertension', 'heart disease', 'heart failure'],
    calorieTarget: 1800,
    meals: [
      { slot: 'early_morning', items: ['Warm water', 'A few walnuts'] },
      { slot: 'breakfast', items: ['Vegetable poha (no added salt at the table)', 'Or: idli with sambar (less salt)'] },
      { slot: 'mid_morning', items: ['1 fruit (papaya / orange)'] },
      { slot: 'lunch', items: ['Brown rice or 2 phulkas', 'Dal and vegetables cooked with little salt and oil', 'Or: steamed / grilled fish'] },
      { slot: 'evening', items: ['Unsalted roasted makhana', 'Herbal tea'] },
      { slot: 'dinner', items: ['Vegetable daliya or 2 phulkas with lauki sabzi', 'Or: chicken stew (skinless, low salt)'] },
      { slot: 'bedtime', items: ['Low-fat milk (small cup), if advised'] },
    ],
    avoid: ['Pickles, papad, chutney powders', 'Processed and packaged foods', 'Extra salt at the table', 'Fried foods and ghee in excess'],
    notes: 'Follow any fluid limit your doctor has given. [REQUIRES CLINICAL GOVERNANCE]',
  },
  {
    code: 'renal',
    name: 'Kidney-friendly (Indian)',
    conditions: ['chronic kidney disease'],
    calorieTarget: 1700,
    meals: [
      { slot: 'breakfast', items: ['Rava upma with vegetables (leached)', 'Or: 1 egg-white omelette with 1 roti'] },
      { slot: 'mid_morning', items: ['1 apple or pear (lower-potassium fruit)'] },
      { slot: 'lunch', items: ['White rice (small cup) or 2 phulkas', 'Leached vegetables (bottle gourd, ridge gourd)', 'Small portion of dal as advised'] },
      { slot: 'evening', items: ['Puffed rice (murmura) without salt', 'Tea (small cup)'] },
      { slot: 'dinner', items: ['2 phulkas with leached vegetable sabzi', 'Or: small portion of chicken as advised'] },
    ],
    avoid: ['High-potassium foods (banana, coconut water, tomato, potato) unless allowed', 'Salt substitutes (contain potassium)', 'Processed and salty foods', 'Excess protein unless prescribed'],
    notes: 'Protein, potassium, phosphorus and fluid limits must be set by the nephrologist/dietitian. [REQUIRES CLINICAL GOVERNANCE]',
  },
];
