/// SRK ELECTRONIC customer-facing service catalogue with owner-approved rates.
///
/// IMPORTANT:
/// Helper policy: across ALL service categories, a helper is optional. The
/// customer chooses whether to book with a helper or without one. When selected,
/// charge the applicable approved helper rate; never force-add a helper.
/// The listed rates are approved for catalogue display. This catalogue is still
/// presentation data only; it is NOT wired to booking submit, dispatch, payment,
/// or technician eligibility until the backend contract is versioned and verified.
/// Do not treat display labels as dispatch identifiers.
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

class SrkServiceTask {
  final String id;
  final String name;

  const SrkServiceTask({required this.id, required this.name});
}

class SrkServiceOption {
  final String name;
  final String? id;
  final String? displayName;
  final List<SrkServiceTask> tasks;
  final List<SrkServiceRate> rates;
  final List<SrkServiceOption> children;
  final String? note;

  const SrkServiceOption({
    required this.name,
    this.id,
    this.displayName,
    this.tasks = const [],
    this.rates = const [],
    this.children = const [],
    this.note,
  });
}

class SrkServiceCategory {
  final String id;
  final String name;
  final String displayName;
  final String iconKey;
  final String description;
  final List<SrkServiceOption> options;
  final List<SrkServiceOption> skillLevels;

  const SrkServiceCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.iconKey,
    required this.description,
    required this.options,
    this.skillLevels = const [],
  });
}

/// Approved catalogue revision. IDs remain local keys, not deployed backend IDs.
/// Keep the legacy constant name to avoid breaking existing app references.
const String srkServiceCatalogDraftVersion = 'approved-2026-11-21.9';

/// Six approved top-level categories, in the owner's requested order.
///
/// Only the rates explicitly listed below are approved. Where a rate is not
/// listed (for example, fridge work or above 20 HP winding), do not calculate
/// or invent a price. Materials/parts are separate from labour and may only be
/// added after customer approval.
const List<SrkServiceCategory> srkServiceCatalog = [
  SrkServiceCategory(
    id: 'electrician',
    name: 'Electrician',
    displayName: 'इलेक्ट्रीशियन',
    iconKey: 'electrical_services',
    description: 'घर, दुकान और फैक्ट्री की इलेक्ट्रिकल सेवाएँ',
    options: [
      SrkServiceOption(
        id: 'expert_electrician',
        name: 'Expert Electrician',
        displayName: 'एक्सपर्ट इलेक्ट्रीशियन',
        children: [
          SrkServiceOption(
            id: 'normal_wiring',
            name: 'Normal Wiring',
            displayName: 'नॉर्मल वायरिंग (घर / दुकान)',
            rates: [
              SrkServiceRate(label: 'बिना Helper', amount: '₹1,000', unit: '8 घंटे'),
              SrkServiceRate(label: 'Helper सहित', amount: '₹1,500', unit: '8 घंटे', helperAmount: '₹62.50 प्रति घंटा अतिरिक्त'),
            ],
          ),
          SrkServiceOption(
            id: 'factory_large_project_wiring',
            name: 'Project Wiring',
            displayName: 'प्रोजेक्ट वायरिंग (बड़ी फैक्ट्री / कंपनी / औद्योगिक भवन)',
            rates: [
              SrkServiceRate(label: 'बिना Helper', amount: '₹400', unit: 'प्रति घंटा'),
              SrkServiceRate(label: 'Helper सहित', amount: '₹550', unit: 'प्रति घंटा', helperAmount: '₹150 प्रति घंटा अतिरिक्त'),
            ],
          ),
        ],
      ),
      SrkServiceOption(id: 'fan_install_repair', name: 'Fan Installation / Repair', displayName: 'पंखा लगाना / मरम्मत'),
      SrkServiceOption(id: 'switch_socket', name: 'Switch & Socket Repair', displayName: 'स्विच और सॉकेट मरम्मत'),
      SrkServiceOption(id: 'light_install', name: 'Light Installation', displayName: 'लाइट लगाना'),
      SrkServiceOption(id: 'mcb_distribution', name: 'MCB / Distribution Board', displayName: 'MCB / डिस्ट्रीब्यूशन बोर्ड'),
      SrkServiceOption(id: 'inverter_battery', name: 'Inverter / Battery', displayName: 'इन्वर्टर / बैटरी'),
      SrkServiceOption(id: 'appliance_electrical', name: 'Appliance Electrical Repair', displayName: 'इलेक्ट्रिकल उपकरण की मरम्मत'),
      SrkServiceOption(id: 'other_electrical', name: 'Other Electrical Work', displayName: 'अन्य इलेक्ट्रिकल काम'),
    ],
    skillLevels: [
      SrkServiceOption(
        name: 'Basic',
        tasks: [
          SrkServiceTask(id: 'basic_bulb_led', name: 'बल्ब और LED लगाना'),
          SrkServiceTask(id: 'basic_tube_light', name: 'ट्यूब लाइट लगाना'),
          SrkServiceTask(id: 'basic_fan_install_remove', name: 'पंखा लगाना और उतारना'),
          SrkServiceTask(id: 'basic_switch_socket', name: 'स्विच और सॉकेट बदलना'),
          SrkServiceTask(id: 'basic_holder_board', name: 'होल्डर और बोर्ड लगाना'),
          SrkServiceTask(id: 'basic_minor_wiring', name: 'छोटी-मोटी वायरिंग ठीक करना'),
          SrkServiceTask(id: 'basic_extension_board', name: 'एक्सटेंशन बोर्ड का काम'),
          SrkServiceTask(id: 'basic_door_bell', name: 'डोर बेल लगाना'),
          SrkServiceTask(id: 'basic_fault_check', name: 'सामान्य बिजली की खराबी जाँचना'),
          SrkServiceTask(id: 'basic_small_home_electrical', name: 'छोटे घरेलू इलेक्ट्रिकल काम'),
        ],
        rates: [
          SrkServiceRate(label: 'मजदूरी', amount: '₹100', unit: 'प्रति घंटा'),
        ],
      ),
      SrkServiceOption(
        name: 'Expert Residential',
        tasks: [
          SrkServiceTask(id: 'expert_home_new_wiring', name: 'पूरे घर की नई वायरिंग'),
          SrkServiceTask(id: 'expert_old_wiring_replace', name: 'पुरानी वायरिंग बदलना'),
          SrkServiceTask(id: 'expert_mcb_db', name: 'MCB और डिस्ट्रीब्यूशन बोर्ड का काम'),
          SrkServiceTask(id: 'expert_inverter_battery', name: 'इन्वर्टर और बैटरी कनेक्शन'),
          SrkServiceTask(id: 'expert_earthing_check', name: 'अर्थिंग की जाँच'),
          SrkServiceTask(id: 'expert_fault_finding', name: 'बिजली की खराबी खोजना'),
          SrkServiceTask(id: 'expert_motor_pump_connection', name: 'मोटर और पंप कनेक्शन'),
          SrkServiceTask(id: 'expert_shop_office_wiring', name: 'दुकान और ऑफिस की वायरिंग'),
          SrkServiceTask(id: 'expert_load_wire_mcb_selection', name: 'लोड के हिसाब से वायर और MCB का चयन'),
        ],
        rates: [
          SrkServiceRate(label: 'बिना Helper', amount: '₹1,000', unit: '8 घंटे'),
          SrkServiceRate(label: 'Helper सहित', amount: '₹1,500', unit: '8 घंटे', helperAmount: '₹62.50 प्रति घंटा अतिरिक्त'),
        ],
      ),
      SrkServiceOption(
        name: 'Factory / Large Project',
        tasks: [
          SrkServiceTask(id: 'factory_full_electrical_wiring', name: 'फैक्ट्री की पूरी इलेक्ट्रिकल वायरिंग'),
          SrkServiceTask(id: 'factory_company_wiring', name: 'बड़ी कंपनियों की वायरिंग'),
          SrkServiceTask(id: 'factory_industrial_building_wiring', name: 'औद्योगिक भवनों की वायरिंग'),
          SrkServiceTask(id: 'factory_three_phase_system', name: 'थ्री-फेज इलेक्ट्रिकल सिस्टम'),
          SrkServiceTask(id: 'factory_large_distribution_panel', name: 'बड़े डिस्ट्रीब्यूशन पैनल'),
          SrkServiceTask(id: 'factory_motor_control_panel', name: 'इंडस्ट्रियल मोटर कंट्रोल पैनल'),
          SrkServiceTask(id: 'factory_star_delta_starter', name: 'स्टार-डेल्टा स्टार्टर'),
          SrkServiceTask(id: 'factory_automatic_control_panel', name: 'ऑटोमैटिक कंट्रोल पैनल'),
          SrkServiceTask(id: 'factory_large_load_fault_check', name: 'बड़े लोड की खराबी की जाँच'),
          SrkServiceTask(id: 'factory_project_team_supervision', name: 'बड़े प्रोजेक्ट की इलेक्ट्रिकल टीम का काम'),
        ],
        rates: [
          SrkServiceRate(label: 'बिना Helper', amount: '₹400', unit: 'प्रति घंटा'),
          SrkServiceRate(label: 'Helper सहित', amount: '₹550', unit: 'प्रति घंटा', helperAmount: '₹150 प्रति घंटा अतिरिक्त'),
        ],
      ),
      SrkServiceOption(
        name: 'Master',
        tasks: [
          SrkServiceTask(id: 'master_project_planning_supervision', name: 'बड़े इलेक्ट्रिकल प्रोजेक्ट की योजना और निगरानी'),
          SrkServiceTask(id: 'master_complex_system_inspection', name: 'जटिल इलेक्ट्रिकल सिस्टम का निरीक्षण'),
          SrkServiceTask(id: 'master_industrial_panel_inspection', name: 'औद्योगिक पैनल और सिस्टम की तकनीकी जाँच'),
          SrkServiceTask(id: 'master_large_load_supply_check', name: 'बड़े लोड और सप्लाई सिस्टम की जाँच'),
          SrkServiceTask(id: 'master_automation_inspection', name: 'ऑटोमेशन सिस्टम का निरीक्षण'),
          SrkServiceTask(id: 'master_electrical_drawing_design', name: 'इलेक्ट्रिकल ड्राइंग और डिजाइन समझना'),
          SrkServiceTask(id: 'master_safety_quality_check', name: 'सुरक्षा और गुणवत्ता की जाँच'),
          SrkServiceTask(id: 'master_team_management', name: 'पूरी इलेक्ट्रिकल टीम का प्रबंधन'),
          SrkServiceTask(id: 'master_testing_commissioning', name: 'प्रोजेक्ट की टेस्टिंग और कमीशनिंग'),
          SrkServiceTask(id: 'master_technical_problem_solving', name: 'तकनीकी समस्या का समाधान और सुपरविजन'),
        ],
        rates: [
          SrkServiceRate(label: 'बिना Helper', amount: '₹700', unit: 'प्रति घंटा'),
          SrkServiceRate(label: 'Helper सहित', amount: '₹950', unit: 'प्रति घंटा', helperAmount: '₹250 प्रति घंटा अतिरिक्त'),
        ],
      ),
    ],
  ),
  SrkServiceCategory(
    id: 'plumber',
    name: 'Plumber',
    displayName: 'प्लंबर',
    iconKey: 'plumbing',
    description: 'पाइप, नल, फिटिंग और प्लंबिंग कार्य',
    options: [],
    skillLevels: [
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
    id: 'painter',
    name: 'Painter',
    displayName: 'पेंटर',
    iconKey: 'format_paint',
    description: 'घर, दुकान और कमर्शियल पेंटिंग',
    options: [],
    skillLevels: [
      SrkServiceOption(name: 'Basic', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹700', unit: '8 घंटे'),
      ]),
      SrkServiceOption(name: 'Expert', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹900', unit: '8 घंटे', helperAmount: 'Helper ₹75 प्रति घंटा अतिरिक्त'),
      ]),
      SrkServiceOption(name: 'Master / Commercial', rates: [
        SrkServiceRate(label: 'मजदूरी', amount: '₹1,200', unit: '8 घंटे', helperAmount: 'Helper ₹100 प्रति घंटा अतिरिक्त'),
      ]),
    ],
  ),
  SrkServiceCategory(
    id: 'ac_fridge',
    name: 'AC + Fridge',
    displayName: 'AC + फ्रिज',
    iconKey: 'ac_unit',
    description: 'पहले AC या Fridge चुनें, फिर उसी की सर्विस',
    options: [
      SrkServiceOption(id: 'ac', name: 'AC', displayName: 'AC', tasks: [
        SrkServiceTask(id: 'ac_repair', name: 'AC रिपेयर'),
        SrkServiceTask(id: 'installation', name: 'इंस्टॉलेशन'),
        SrkServiceTask(id: 'uninstallation', name: 'अनइंस्टॉलेशन'),
        SrkServiceTask(id: 'servicing', name: 'सर्विसिंग'),
        SrkServiceTask(id: 'gas_charging', name: 'गैस चार्जिंग'),
        SrkServiceTask(id: 'leakage_check', name: 'लीकेज जाँच'),
        SrkServiceTask(id: 'ac_compressor', name: 'कंप्रेसर'),
        SrkServiceTask(id: 'ac_pcb', name: 'PCB'),
      ], rates: [
        SrkServiceRate(label: 'AC मैकेनिक की मजदूरी', amount: '₹250', unit: 'प्रति घंटा', helperAmount: 'Helper ₹150 प्रति घंटा अतिरिक्त', note: 'मैकेनिक और हेल्पर साथ होने पर कुल ₹400 प्रति घंटा। सामान / पार्ट्स अलग; ग्राहक की मंजूरी के बाद।'),
      ], note: 'Installation, Uninstallation, Repair, Servicing, Gas Charging, Leakage Check, Compressor और PCB'),
      SrkServiceOption(id: 'fridge', name: 'Fridge', displayName: 'फ्रिज', tasks: [
        SrkServiceTask(id: 'fridge_repair', name: 'फ्रिज रिपेयर'),
        SrkServiceTask(id: 'cooling_problem', name: 'कूलिंग समस्या'),
        SrkServiceTask(id: 'fridge_compressor', name: 'कंप्रेसर'),
        SrkServiceTask(id: 'fridge_gas_leakage', name: 'गैस / लीकेज'),
        SrkServiceTask(id: 'fridge_pcb_other_repair', name: 'PCB और अन्य मरम्मत'),
      ], rates: [
        SrkServiceRate(
          label: 'फ्रिज टेक्नीशियन की मजदूरी',
          amount: '₹200',
          unit: 'प्रति घंटा',
          helperAmount: 'Helper ₹100 प्रति घंटा अतिरिक्त',
        ),
      ], note: 'Refrigerator Repair, Cooling Problem, Compressor, Gas / Leakage, PCB और Other Repair. पार्ट्स अलग; ग्राहक की मंजूरी के बाद।'),
    ],
  ),
  SrkServiceCategory(
    id: 'motor_pump',
    name: 'Motor & Pump',
    displayName: 'मोटर और पंप',
    iconKey: 'water',
    description: 'मोटर, टुल्लू पंप और सबमर्सिबल सेवाएँ',
    options: [
      SrkServiceOption(id: 'tullu_pump', name: 'Domestic Tullu Pump', displayName: 'घरेलू टुल्लू पंप'),
      SrkServiceOption(id: 'pump_repair', name: 'Pump Repair', displayName: 'पंप रिपेयर'),
      SrkServiceOption(id: 'submersible', name: 'Submersible Pump', displayName: 'सबमर्सिबल पंप'),
      SrkServiceOption(
        id: 'motor_pump_mechanic_charge',
        name: 'Motor / Pump Mechanic Charge',
        displayName: 'मोटर-पंप मैकेनिक चार्ज',
        rates: [
          SrkServiceRate(label: '0.5 HP', amount: '₹500', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '1 HP', amount: '₹600', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '1.5 HP', amount: '₹700', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '2 HP', amount: '₹800', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '3 HP', amount: '₹900', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '5 HP', amount: '₹1,000', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '7.5 HP', amount: '₹1,100', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '10 HP', amount: '₹1,200', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '15 HP', amount: '₹1,300', unit: 'एक बार का फिक्स चार्ज'),
          SrkServiceRate(label: '20 HP', amount: '₹1,400', unit: 'एक बार का फिक्स चार्ज'),
        ],
        note: 'इसमें जाँच, खोलना, ले जाना, बनवाकर वापस लाना और फिटिंग शामिल है। वाइंडिंग और सामान का खर्च अलग; ग्राहक की मंजूरी के बाद।',
      ),
      SrkServiceOption(id: 'winding', name: 'Winding', displayName: 'वाइंडिंग', rates: [
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
      SrkServiceOption(id: 'capacitor', name: 'Capacitor', displayName: 'कैपेसिटर'),
      SrkServiceOption(id: 'starter', name: 'Starter', displayName: 'स्टार्टर'),
      SrkServiceOption(id: 'installation_removal', name: 'Installation / Removal', displayName: 'इंस्टॉलेशन / हटाना'),
    ],
  ),
  SrkServiceCategory(
    id: 'cooler',
    name: 'Cooler',
    displayName: 'कूलर',
    iconKey: 'mode_fan',
    description: 'कूलर रिपेयर',
    options: [
      SrkServiceOption(id: 'cooler_repair', name: 'Cooler Repair', displayName: 'कूलर रिपेयर', rates: [
        SrkServiceRate(label: 'लेबर चार्ज', amount: '₹500', unit: 'प्रति कूलर फिक्स'),
      ], note: 'पार्ट्स अलग; ग्राहक की मंजूरी के बाद। Motor winding इस दर में शामिल नहीं।'),
    ],
  ),
];
