/// Formata uma data no padrão dd/mm/aaaa (ou "—" quando nula).
String formatDate(DateTime? date) {
  if (date == null) return '—';
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}