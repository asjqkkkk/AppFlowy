import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

class AvatarPage extends StatelessWidget {
  const AvatarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Avatar with Name (Initials)'),
          Wrap(
            spacing: 16,
            children: [
              AFAvatar(
                  name: 'Lucas',
                  size: AFAvatarSize.xs,
                  email: 'lucas@example.com'),
              AFAvatar(
                  name: 'Vivian',
                  size: AFAvatarSize.s,
                  email: 'vivian@example.com'),
              AFAvatar(
                  name: 'John',
                  size: AFAvatarSize.m,
                  email: 'john@example.com'),
              AFAvatar(
                  name: 'Cindy',
                  size: AFAvatarSize.l,
                  email: 'cindy@example.com'),
              AFAvatar(
                  name: 'Alex',
                  size: AFAvatarSize.xl,
                  email: 'alex@example.com'),
            ],
          ),
          const SizedBox(height: 32),
          _sectionTitle('Avatar with Image URL'),
          Wrap(
            spacing: 16,
            children: [
              AFAvatar(
                url: 'https://avatar.iran.liara.run/public/35',
                size: AFAvatarSize.xs,
                email: 'lucas@example.com',
              ),
              AFAvatar(
                url: 'https://avatar.iran.liara.run/public/36',
                size: AFAvatarSize.s,
                email: 'vivian@example.com',
              ),
              AFAvatar(
                url: 'https://avatar.iran.liara.run/public/37',
                size: AFAvatarSize.m,
                email: 'john@example.com',
              ),
              AFAvatar(
                url: 'https://avatar.iran.liara.run/public/38',
                size: AFAvatarSize.l,
                email: 'cindy@example.com',
              ),
              AFAvatar(
                url: 'https://avatar.iran.liara.run/public/39',
                size: AFAvatarSize.xl,
                email: 'alex@example.com',
              ),
            ],
          ),
          const SizedBox(height: 32),
          _sectionTitle('Custom Colors'),
          Wrap(
            spacing: 16,
            children: [
              AFAvatar(
                name: 'Nina',
                size: AFAvatarSize.l,
                backgroundColor: Colors.deepPurple,
                textColor: Colors.white,
                email: 'nina@example.com',
              ),
              AFAvatar(
                name: 'Lucas Xu',
                size: AFAvatarSize.l,
                backgroundColor: Colors.amber,
                textColor: Colors.black,
                email: 'lucas@example.com',
              ),
              AFAvatar(
                name: 'A',
                size: AFAvatarSize.l,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                email: 'a@example.com',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
}
