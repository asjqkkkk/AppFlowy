import 'package:appflowy/features/workspace/workspace.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
import 'package:appflowy/mobile/presentation/database/mobile_calendar_events_empty.dart';
import 'package:appflowy/plugins/database/calendar/application/calendar_bloc.dart';
import 'package:appflowy/plugins/database/calendar/presentation/calendar_event_card.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> pushMobileCalendarEventsScreen(
  BuildContext context, {
  required List<CalendarDayEvent> events,
  required DateTime date,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: context.read<CalendarBloc>(),
            ),
            BlocProvider.value(
              value: context.read<UserWorkspaceBloc>(),
            ),
          ],
          child: MobileCalendarEventsScreen(
            date: date,
            events: events,
          ),
        );
      },
    ),
  );
}

class MobileCalendarEventsScreen extends StatefulWidget {
  const MobileCalendarEventsScreen({
    super.key,
    required this.date,
    required this.events,
  });

  final DateTime date;
  final List<CalendarDayEvent> events;

  @override
  State<MobileCalendarEventsScreen> createState() =>
      _MobileCalendarEventsScreenState();
}

class _MobileCalendarEventsScreenState
    extends State<MobileCalendarEventsScreen> {
  late final List<CalendarDayEvent> _events = widget.events;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const Key('add_event_fab'),
        elevation: 6,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () => context
            .read<CalendarBloc>()
            .add(CalendarEvent.createEvent(widget.date)),
        child: const Text('+'),
      ),
      appBar: FlowyAppBar(
        titleText: DateFormat.yMMMMd(context.locale.toLanguageTag())
            .format(widget.date),
      ),
      body: BlocBuilder<CalendarBloc, CalendarState>(
        buildWhen: (p, c) =>
            p.newEvent != c.newEvent &&
            c.newEvent?.date.withoutTime == widget.date,
        builder: (context, state) {
          if (state.newEvent?.event != null &&
              _events
                  .none((e) => e.eventId == state.newEvent!.event!.eventId) &&
              state.newEvent!.date.withoutTime == widget.date) {
            _events.add(state.newEvent!.event!);
          }

          if (_events.isEmpty) {
            return const MobileCalendarEventsEmpty();
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const VSpace(10),
                ..._events.map((event) {
                  return EventCard(
                    databaseController:
                        context.read<CalendarBloc>().databaseController,
                    event: event,
                    constraints: const BoxConstraints.expand(),
                    autoEdit: false,
                    isDraggable: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                  );
                }),
                const VSpace(24),
              ],
            ),
          );
        },
      ),
    );
  }
}
