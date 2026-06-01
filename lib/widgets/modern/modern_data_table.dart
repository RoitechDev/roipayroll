import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';

class DataTableColumn<T> {
  final String id;
  final String label;
  final double width;
  final bool sortable;
  final Alignment alignment;
  final Widget Function(T item) builder;

  const DataTableColumn({
    required this.id,
    required this.label,
    required this.width,
    required this.builder,
    this.sortable = false,
    this.alignment = Alignment.centerLeft,
  });
}

class TableAction {
  final String id;
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const TableAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

class TableActionsMenu extends StatelessWidget {
  final List<TableAction> actions;

  const TableActionsMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TableAction>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) {
        return actions
            .map(
              (action) => PopupMenuItem<TableAction>(
                value: action,
                child: Row(
                  children: [
                    Icon(
                      action.icon,
                      size: 18,
                      color: action.color ?? AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      action.label,
                      style: TextStyle(
                        color: action.color ?? AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList();
      },
      onSelected: (action) => action.onTap(),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const StatusBadge({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class ModernDataTable<T> extends StatefulWidget {
  final List<T> items;
  final List<DataTableColumn<T>> columns;
  final Set<String> selectedItems;
  final String Function(T item)? itemId;
  final void Function(Set<String> ids)? onSelectionChanged;
  final void Function(T item)? onRowTap;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field, bool ascending)? onSort;

  const ModernDataTable({
    super.key,
    required this.items,
    required this.columns,
    required this.selectedItems,
    this.itemId,
    this.onSelectionChanged,
    this.onRowTap,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
  });

  @override
  State<ModernDataTable<T>> createState() => _ModernDataTableState<T>();
}

class _ModernDataTableState<T> extends State<ModernDataTable<T>> {
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idResolver =
        widget.itemId ?? (T item) => item.hashCode.toString();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        thumbVisibility: true,
        controller: _verticalController,
        child: SingleChildScrollView(
          primary: false,
          controller: _verticalController,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.columns
                    .fold<double>(0.0, (sum, col) => sum + col.width),
              ),
              child: DataTable(
                showCheckboxColumn: true,
                headingRowColor: const WidgetStatePropertyAll(
                  AppColors.surfaceVariant,
                ),
                columns: widget.columns
                    .map(
                      (column) => DataColumn(
                        onSort: column.sortable
                            ? (columnIndex, ascending) {
                                widget.onSort?.call(column.id, ascending);
                              }
                            : null,
                        label: SizedBox(
                          width: column.width,
                          child: Text(
                            column.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                rows: widget.items.map((item) {
                  final itemKey = idResolver(item);
                  final selected = widget.selectedItems.contains(itemKey);

                  return DataRow(
                    selected: selected,
                    onSelectChanged: widget.onSelectionChanged == null
                        ? null
                        : (value) {
                            final next = <String>{...widget.selectedItems};
                            if (value == true) {
                              next.add(itemKey);
                            } else {
                              next.remove(itemKey);
                            }
                            widget.onSelectionChanged!(next);
                          },
                    onLongPress: widget.onRowTap == null
                        ? null
                        : () => widget.onRowTap!(item),
                    cells: widget.columns
                        .map(
                          (column) => DataCell(
                            SizedBox(
                              width: column.width,
                              child: Align(
                                alignment: column.alignment,
                                child: column.builder(item),
                              ),
                            ),
                            onTap:
                                widget.onRowTap == null
                                    ? null
                                    : () => widget.onRowTap!(item),
                          ),
                        )
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
