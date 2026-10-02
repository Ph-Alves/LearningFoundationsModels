import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]

    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskNotes = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    NavigationLink(value: task) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.headline)
                            if !task.savedChallenges.isEmpty {
                                Text("\(task.savedChallenges.count) saved challenge(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Tasks")
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New task", systemImage: "plus") {
                        isAddingTask = true
                    }
                }
            }
            .overlay {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No tasks yet",
                        systemImage: "figure.run",
                        description: Text("Create a task, like \"Swimming\", to get mental friction challenges.")
                    )
                }
            }
            .sheet(isPresented: $isAddingTask) {
                NavigationStack {
                    Form {
                        TextField("Title, e.g. Swimming", text: $newTaskTitle)
                        TextField("Notes (optional)", text: $newTaskNotes, axis: .vertical)
                    }
                    .navigationTitle("New task")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isAddingTask = false
                                resetForm()
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                addTask()
                            }
                            .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func addTask() {
        let task = TaskItem(title: newTaskTitle.trimmingCharacters(in: .whitespaces), notes: newTaskNotes)
        modelContext.insert(task)
        isAddingTask = false
        resetForm()
    }

    private func resetForm() {
        newTaskTitle = ""
        newTaskNotes = ""
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tasks[index])
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
