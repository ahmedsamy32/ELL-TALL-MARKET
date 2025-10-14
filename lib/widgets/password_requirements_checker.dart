import 'package:flutter/material.dart';

class PasswordRequirementsChecker extends StatelessWidget {
  final String password;

  const PasswordRequirementsChecker({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'متطلبات كلمة المرور:',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequirementItem('على الأقل 8 أحرف', false),
            _buildRequirementItem('حرف كبير (A-Z)', false),
            _buildRequirementItem('حرف صغير (a-z)', false),
            _buildRequirementItem('رقم واحد على الأقل (0-9)', false),
            _buildRequirementItem('رمز خاص (!@#\$%^&*...)', false),
            _buildRequirementItem('بدون مسافات', true),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'متطلبات كلمة المرور:',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem('على الأقل 8 أحرف', password.length >= 8),
          _buildRequirementItem(
            'حرف كبير (A-Z)',
            RegExp(r'[A-Z]').hasMatch(password),
          ),
          _buildRequirementItem(
            'حرف صغير (a-z)',
            RegExp(r'[a-z]').hasMatch(password),
          ),
          _buildRequirementItem(
            'رقم واحد على الأقل (0-9)',
            RegExp(r'[0-9]').hasMatch(password),
          ),
          _buildRequirementItem(
            'رمز خاص (!@#\$%^&*...)',
            RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
          ),
          _buildRequirementItem('بدون مسافات', !password.contains(' ')),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isValid ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isValid ? Colors.green.shade400 : Colors.red.shade400,
                width: 1.5,
              ),
            ),
            child: Icon(
              isValid ? Icons.check : Icons.close,
              size: 14,
              color: isValid ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isValid ? Colors.green.shade700 : Colors.red.shade700,
                fontSize: 13,
                fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
