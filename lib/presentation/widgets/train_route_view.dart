import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/time_utils.dart';
import '../../domain/entities/service_entity.dart';

class TrainRouteView extends StatelessWidget {
  final ServiceEntity service;
  final String queryFrom;
  final String queryTo;
  final String effectiveDay;
  final ScrollController? scrollController;
  final VoidCallback? onClose;

  const TrainRouteView({
    super.key,
    required this.service,
    required this.queryFrom,
    required this.queryTo,
    required this.effectiveDay,
    this.scrollController,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final stopsList = service.stops;
    final isOffToday = service.offDays.contains(effectiveDay);
    final isToday = (effectiveDay == todayName());
    final curMinutes = minutesNow();

    // Compute times for each stop
    final List<int> times = [];
    int prevTime = service.departureMinutes;
    for (int i = 0; i < stopsList.length; i++) {
      final stop = stopsList[i];
      if (service.stopTimings.containsKey(stop)) {
        prevTime = service.stopTimings[stop]!;
      } else if (i > 0) {
        prevTime += 15;
      }
      times.add(prevTime);
    }

    final int originTime = times.isNotEmpty ? times.first : service.departureMinutes;
    final int finalTime = times.isNotEmpty ? times.last : (service.departureMinutes + 30);
    final int totalDuration = (finalTime - originTime);

    final int boardIdx = stopsList.indexWhere(
      (s) => s.trim().toLowerCase() == queryFrom.trim().toLowerCase(),
    );
    final int destIdx = stopsList.indexWhere(
      (s) => s.trim().toLowerCase() == queryTo.trim().toLowerCase(),
    );
    final bool hasSegment = boardIdx >= 0 && destIdx > boardIdx;

    int liveBusStopIndex = -1;
    bool tripCompleted = false;
    bool tripNotStarted = false;

    if (isToday && !isOffToday && times.isNotEmpty) {
      if (curMinutes < times.first) {
        tripNotStarted = true;
      } else if (curMinutes > times.last) {
        tripCompleted = true;
      } else {
        for (int i = times.length - 1; i >= 0; i--) {
          if (curMinutes >= times[i]) {
            liveBusStopIndex = i;
            break;
          }
        }
      }
    }

    String statusText;
    Color statusBg;
    Color statusFg;
    IconData statusIcon;

    if (isOffToday) {
      statusText = 'No service on $effectiveDay (Off: ${service.offDays.join(', ')})';
      statusBg = Colors.deepOrange.shade50;
      statusFg = Colors.deepOrange.shade900;
      statusIcon = Icons.warning_amber_rounded;
    } else if (!isToday) {
      statusText = 'Scheduled for $effectiveDay • Departs at ${timeLabel(originTime)}';
      statusBg = AppColors.secondaryContainer;
      statusFg = AppColors.onSecondaryContainer;
      statusIcon = Icons.calendar_today;
    } else if (tripNotStarted) {
      final waitM = times.first - curMinutes;
      statusText = 'Yet to depart • Starts in $waitM mins (${timeLabel(times.first)})';
      statusBg = Colors.teal.shade50;
      statusFg = Colors.teal.shade900;
      statusIcon = Icons.timer_outlined;
    } else if (tripCompleted) {
      statusText = 'Completed today\'s run (${timeLabel(times.last)})';
      statusBg = Colors.grey.shade100;
      statusFg = Colors.grey.shade800;
      statusIcon = Icons.task_alt;
    } else {
      final nextIdx = (liveBusStopIndex + 1 < stopsList.length)
          ? liveBusStopIndex + 1
          : liveBusStopIndex;
      final nextStop = stopsList[nextIdx];
      final nextTime = times[nextIdx];
      final diff = nextTime - curMinutes;
      statusText = diff > 0
          ? 'Live: Arriving at $nextStop in $diff mins (${timeLabel(nextTime)})'
          : 'Live: At $nextStop station now';
      statusBg = Colors.green.shade50;
      statusFg = Colors.green.shade900;
      statusIcon = Icons.directions_bus;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top header gradient banner
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryContainer,
                AppColors.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.busName,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${service.businessName} • ${service.routeName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeLabel(originTime),
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stopsList.isNotEmpty ? stopsList.first : 'Origin',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Text(
                          '${totalDuration ~/ 60 > 0 ? "${totalDuration ~/ 60}h " : ""}${totalDuration % 60}m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 60,
                              height: 2,
                              color: Colors.white54,
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        Text(
                          '${stopsList.length} Stops',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeLabel(finalTime),
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stopsList.isNotEmpty ? stopsList.last : 'Final',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live status banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: statusBg,
          child: Row(
            children: [
              Icon(statusIcon, size: 16, color: statusFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Passenger's Trip Highlight
        if (hasSegment)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              border: Border(
                bottom: BorderSide(color: Colors.green.shade200),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your Trip: ${stopsList[boardIdx]} (${timeLabel(times[boardIdx])}) → ${stopsList[destIdx]} (${timeLabel(times[destIdx])}) • ${times[destIdx] - times[boardIdx]} mins (${destIdx - boardIdx} stops)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Intermediate stops ladder
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: stopsList.length,
            itemBuilder: (context, i) {
              final stopName = stopsList[i];
              final stopTime = times[i];
              final isFirst = i == 0;
              final isLast = i == stopsList.length - 1;
              final isBoarding = i == boardIdx;
              final isDest = i == destIdx;
              final inSegment = hasSegment && (i >= boardIdx && i <= destIdx);
              final isPassed = isToday &&
                  !isOffToday &&
                  !tripNotStarted &&
                  (tripCompleted || i <= liveBusStopIndex);
              final isLiveHere = isToday &&
                  !isOffToday &&
                  !tripNotStarted &&
                  !tripCompleted &&
                  (i == liveBusStopIndex);

              final Color topTrackColor =
                  (hasSegment && i > boardIdx && i <= destIdx)
                      ? AppColors.primary
                      : (isPassed
                          ? Colors.teal.shade200
                          : Colors.grey.shade300);
              final Color bottomTrackColor =
                  (hasSegment && i >= boardIdx && i < destIdx)
                      ? AppColors.primary
                      : (isPassed && i < liveBusStopIndex
                          ? Colors.teal.shade200
                          : Colors.grey.shade300);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            timeLabel(stopTime),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: (isBoarding || isDest || isLiveHere)
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isBoarding
                                  ? Colors.green.shade800
                                  : (isDest
                                      ? Colors.red.shade800
                                      : (isPassed
                                          ? Colors.grey.shade500
                                          : AppColors.onSurface)),
                            ),
                          ),
                          if (i > 0)
                            Text(
                              '+${stopTime - times[i - 1]}m',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!isFirst)
                            Positioned(
                              top: 0,
                              bottom: 24,
                              child: Container(
                                width: (hasSegment &&
                                        i > boardIdx &&
                                        i <= destIdx)
                                    ? 4
                                    : 2,
                                color: topTrackColor,
                              ),
                            ),
                          if (!isLast)
                            Positioned(
                              top: 24,
                              bottom: 0,
                              child: Container(
                                width: (hasSegment &&
                                        i >= boardIdx &&
                                        i < destIdx)
                                    ? 4
                                    : 2,
                                color: bottomTrackColor,
                              ),
                            ),
                          Positioned(
                            top: 10,
                            child: isLiveHere
                                ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.directions_bus,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  )
                                : isBoarding
                                    ? Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.my_location,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      )
                                    : isDest
                                        ? Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: inSegment
                                                  ? AppColors.primary
                                                  : (isPassed
                                                      ? Colors.teal.shade300
                                                      : Colors.white),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: inSegment
                                                    ? AppColors.primary
                                                    : Colors.grey.shade400,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    stopName,
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize:
                                          (isBoarding || isDest) ? 15 : 14,
                                      fontWeight: (isBoarding ||
                                              isDest ||
                                              isFirst ||
                                              isLast)
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isBoarding
                                          ? Colors.green.shade900
                                          : (isDest
                                              ? Colors.red.shade900
                                              : (isPassed && !isLiveHere
                                                  ? Colors.grey.shade600
                                                  : AppColors.onSurface)),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Stop #${i + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (isLiveHere)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '🚌 BUS IS HERE NOW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                if (isBoarding)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.green.shade400,
                                      ),
                                    ),
                                    child: Text(
                                      '🟢 YOUR BOARDING STOP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                if (isDest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                    child: Text(
                                      '🔴 YOUR DESTINATION STOP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLow,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Train-style timetable track',
                style:
                    TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: onClose ?? () => Navigator.pop(context),
                child: const Text('Close Route'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
