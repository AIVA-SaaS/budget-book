/// Email policy helpers — mirrors BE EmailPolicy.
///
/// Kakao users who did not consent to email sharing receive a placeholder
/// address in the form `{provider}_{providerId}@no-email.local`.
/// An empty string is also treated as "not registered".
///
/// All screens must use [isPlaceholderEmail] / [User.hasRegisteredEmail]
/// from this single location — never inline the check.
const String _placeholderSuffix = '@no-email.local';

/// Returns true when [email] is a placeholder or empty, meaning the user
/// has not registered a real email address.
bool isPlaceholderEmail(String email) {
  return email.isEmpty || email.endsWith(_placeholderSuffix);
}
