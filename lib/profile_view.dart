import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'navigation.dart';
import 'overview_frame.dart';
import 'profile_menu.dart';
import 'profile_model.dart';
import 'view_model.dart';

class ProfileView extends StatefulWidget {
  final ViewModel model;
  const ProfileView({super.key, required this.model});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final ProfileModel profile;
  final first = TextEditingController(), last = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    profile = ProfileModel(ProfileRepository(widget.model.repository.api));
    load();
  }

  Future<void> load() async {
    if (await profile.load() && mounted) {
      first.text = profile.profile!.firstName;
      last.text = profile.profile!.lastName;
    }
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: profile,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final user = profile.profile;
      Widget card(List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
      Widget field(TextEditingController controller, String label) =>
          TextFormField(
            controller: controller,
            enabled: !profile.busy,
            maxLength: 100,
            decoration: InputDecoration(labelText: label, counterText: ''),
            textInputAction: TextInputAction.next,
            autofillHints: [
              controller == first
                  ? AutofillHints.givenName
                  : AutofillHints.familyName,
            ],
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l.validationError : null,
          );
      Widget methodRow(String key, String title) {
        final configured = user?.authenticationMethods[key];
        final colors = Theme.of(context).colorScheme;
        final information = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              configured == null
                  ? l.methodUnknown
                  : configured
                  ? l.methodConfigured
                  : l.methodNotConfigured,
              style: TextStyle(
                color: configured == true
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        );
        final button = OutlinedButton(
          onPressed: profile.busy
              ? null
              : () => navigate(
                  configured == true && key != 'password'
                      ? '/auth/profile/security'
                      : '/auth/account/$key',
                ),
          child: Text(configured == true ? l.manageMethod : l.setupMethod),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 440
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [information, const SizedBox(height: 8), button],
                  )
                : Row(
                    children: [
                      Expanded(child: information),
                      const SizedBox(width: 16),
                      button,
                    ],
                  ),
          ),
        );
      }

      return WorkspaceScaffold(
        appBar: WorkspaceAppBar(
          model: widget.model,
          busy: profile.busy,
          automaticallyImplyLeading: false,
          title: Text(l.profile),
        ),
        body: AppNavigationFrame(
          model: widget.model,
          selectedIndex: -1,
          sectionRoot: false,
          busy: profile.busy,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    l.editProfile,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  if (profile.busy) const LinearProgressIndicator(),
                  if (profile.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorText(l, profile.error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (user == null && !profile.busy)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: load,
                        child: Text(l.retryProfile),
                      ),
                    ),
                  if (user != null) ...[
                    card([
                      Row(
                        children: [
                          const ProfileIcon(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.personalInfo,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: form,
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              constraints.maxWidth >= 550
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: field(first, l.firstName)),
                                    const SizedBox(width: 16),
                                    Expanded(child: field(last, l.lastName)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    field(first, l.firstName),
                                    const SizedBox(height: 16),
                                    field(last, l.lastName),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: profile.busy
                              ? null
                              : () async {
                                  if (!form.currentState!.validate()) return;
                                  if (await profile.save(
                                        first.text,
                                        last.text,
                                      ) &&
                                      context.mounted) {
                                    first.text = profile.profile!.firstName;
                                    last.text = profile.profile!.lastName;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l.profileSaved)),
                                    );
                                  }
                                },
                          child: Text(l.save),
                        ),
                      ),
                    ]),
                    card([
                      Text(
                        l.profileEmail,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(user.email),
                      const SizedBox(height: 12),
                      Text(l.profileEmailHelp),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: profile.busy
                              ? null
                              : () => navigate('/auth/account/email'),
                          child: Text(l.changeEmail),
                        ),
                      ),
                    ]),
                    card([
                      Text(
                        l.profileSecurity,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(l.profileSecurityHelp),
                      const SizedBox(height: 20),
                      for (final entry in {
                        'password': l.methodPassword,
                        'otp': l.methodOtp,
                        'passkey': l.methodPasskey,
                        'recovery': l.methodRecovery,
                      }.entries) ...[
                        methodRow(entry.key, entry.value),
                        if (entry.key != 'recovery') const Divider(height: 1),
                      ],
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
