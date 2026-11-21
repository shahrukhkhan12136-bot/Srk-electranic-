/// SRK ELECTRONIC canonical customer-facing service catalogue draft.
///
/// IMPORTANT:
/// This catalogue is presentation data only. It is NOT wired to booking submit,
/// dispatch, payment, or technician eligibility until the backend contract is
/// versioned and verified. Do not treat display labels as dispatch identifiers.
class SrkServiceRate {
  final String label;
  final String amount;
  final String unit;
  final String? helperAmount;
  final String? note;

  const SrkServiceRate({
    required this.label,
    required this.amount,
    required this.unit,
    this.helperAmount,
    this.note,
  });
}

class SrkServiceOption {
  final String name;
  final List<SrkServiceRate> rates;
  final String? note;

  const SrkServiceOption({
    required this.name,
    this.rates = const [],
    this.note,
  });
}

class SrkServiceCategory {
  final String name;
  final String description;
  final List<SrkServiceOption> options;

  const SrkServiceCategory({
    required this.name,
    required this.description,
    required this.options,
  });
}

/// Six approved top-level categories, in the owner's requested order.
///
/// Rates intentionally omit unconfirmed prices. Materials/parts are separate
/// from labour and may only be added after customer approval.
const List<SrkServiceCategory> srkServiceCatalog = [
  SrkServiceCategory(
    name: 'Electrician',
    description: 'घर, दुकान और फैक्ट्री की इलेक्ट्रिकल सेवाएँ',
    options: [
      SrkServiceOption(name: 'Electrical Wiring'),
      SrkServiceOption(name: 'Fan Installation / Repair'),
      SrkServiceOption(name: 'Switch & Socket Repair'),
      SrkServiceOption(name: 'Light Installation'),
      SrkServiceOption(name: 'MCB / Distribution Board'),
      SrkServiceOption(name: 'Inverter / Battery'),
      SrkServiceOption(name: 'Appliance Electrical Repair'),
      SrkServiceOption(name: 'Other Electrical Work'),
      SrkServiceOption(
        name: 'Basic',
        rates: [SrkServiceRate(label: 'मजदूरी', amount: '₹100', unit: 'प्रति घंटा')],
      ),
      SrkServiceOption(
        name: 'Expert Residential',
        rates: [
          SrkServiceRate(label: 'बिना Helper', amount: '₹1,000', unit: '8 घंटे'),
          SrkServiceRate(label: 'Helper सहित', amount: '₹1,500', unit: '8 घंटे', helperAmount: '₹62.50 प्रति घंटा अतिरिक्त'),
        ],
      ),
      SrkServiceOption(
        name: 'Factory / Large Project',
        rates: [
          SrkServiceRate(label: 'बिना Helper', amount: '₹400', unit: 'प्रति घंटा'),
          SrkServiceRate(label: 'Helper सहित', amount: '₹550', unit: 'प्रति घंटा', helperAmount: '₹150 प्रति घंटा अतिरिक्त'),
        ],
      ),
      SrkServiceOption(
        name: 'Master',
        rates: [
          SrkServiceRate(label: 'बिना Helper', amount: '₹700', unit: 'प्रति घंटा'),
          SrkServiceRate(label: 'Helper सहित', amount: '₹950', unit: 'प्रति घंटा', helperAmount: '₹250 प्रति घंटा अतिरिक्त'),
        ],
      ),
    ],
  ),
  SrkServiceCategory(
    name: 'Plumber',
    description: 'पाइप, नल, फिटिंग और प्लंबिंग कार्य',
    options: [
      SrkServiceOption(name: 'Basic', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹100', unit: 'प्रति घंटा', helperAmount: 'Helper ₹50 प्रति घंटा; कुल ₹150 प्रति घंटा'),
      ]),
      SrkServiceOption(name: 'Expert', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹150', unit: 'प्रति घंटा', helperAmount: 'Helper ₹75 प्रति घंटा; कुल ₹225 प्रति घंटा'),
      ]),
      SrkServiceOption(name: 'Master / Industrial', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹225', unit: 'प्रति घंटा', helperAmount: 'Helper ₹100 प्रति घंटा; कुल ₹325 प्रति घंटा'),
      ]),
    ],
  ),
  SrkServiceCategory(
    name: 'Painter',
    description: 'घर, दुकान और कमर्शियल पेंटिंग',
    options: [
      SrkServiceOption(name: 'Basic', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹700', unit: '8 घंटे'),
      ]),
      SrkServiceOption(name: 'Expert', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹900', unit: '8 घंटे', helperAmount: 'Helper ₹75 अतिरिक्त'),
      ]),
      SrkServiceOption(name: 'Master / Commercial', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹1,200', unit: '8 घंटे', helperAmount: 'Helper ₹100 अतिरिक्त'),
      ]),
    ],
  ),
  SrkServiceCategory(
    name: 'AC + Fridge',
    description: 'पहले AC या Fridge चुनें, फिर उसी की सर्विस',
    options: [
      SrkServiceOption(name: 'AC', rates: [
        SrkServiceRate(label: 'AC Technician', amount: '₹437', unit: 'प्रति घंटा'),
      ], note: 'Installation, Uninstallation, Repair, Servicing, Gas Charging, Leakage Check, Compressor और PCB'),
      SrkServiceOption(name: 'Fridge', note: 'Refrigerator Repair, Cooling Problem, Compressor, Gas / Leakage, PCB और Other Repair. अंतिम दर की पुष्टि बाकी है।'),
    ],
  ),
  SrkServiceCategory(
    name: 'Motor & Pump',
    description: 'मोटर, टुल्लू पंप और सबमर्सिबल सेवाएँ',
    options: [
      SrkServiceOption(name: 'Domestic Tullu Pump'),
      SrkServiceOption(name: 'Pump Repair'),
      SrkServiceOption(name: 'Submersible Pump'),
      SrkServiceOption(name: 'Winding', rates: [
        SrkServiceRate(label: '0.5 HP', amount: '₹500', unit: 'फिक्स'),
        SrkServiceRate(label: '1 HP', amount: '₹600', unit: 'फिक्स'),
        SrkServiceRate(label: '1.5 HP', amount: '₹700', unit: 'फिक्स'),
        SrkServiceRate(label: '2 HP', amount: '₹800', unit: 'फिक्स'),
        SrkServiceRate(label: '3 HP', amount: '₹900', unit: 'फिक्स'),
        SrkServiceRate(label: '5 HP', amount: '₹1,000', unit: 'फिक्स'),
        SrkServiceRate(label: '7.5 HP', amount: '₹1,100', unit: 'फिक्स'),
        SrkServiceRate(label: '10 HP', amount: '₹1,200', unit: 'फिक्स'),
        SrkServiceRate(label: '15 HP', amount: '₹1,300', unit: 'फिक्स'),
        SrkServiceRate(label: '20 HP', amount: '₹1,400', unit: 'फिक्स'),
      ], note: '20 HP से अधिक की दर की पुष्टि बाकी है। Winding में hourly overtime लागू नहीं।'),
      SrkServiceOption(name: 'Capacitor'),
      SrkServiceOption(name: 'Starter'),
      SrkServiceOption(name: 'Installation / Removal'),
    ],
  ),
  SrkServiceCategory(
    name: 'Cooler',
    description: 'कूलर रिपेयर',
    options: [
      SrkServiceOption(name: 'Cooler Repair', rates: [
        SrkServiceRate(label: 'लेबर चार्ज', amount: '₹500', unit: 'प्रति कूलर फिक्स'),
      ], note: 'पार्ट्स अलग; ग्राहक की मंजूरी के बाद। Motor winding इस दर में शामिल नहीं।'),
    ],
  ),
];
