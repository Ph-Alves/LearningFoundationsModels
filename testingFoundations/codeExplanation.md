
# Explicando o codigo
O codigo do foundations funciona a partir de 5 arquivos:
- ContentView
- FrictionEngine
- Models
- MyApp
- TaskDetailView

Temos 2 views principais, um arquivo com os modelos, uma engine (Foundations) e o arquivo raiz (app).

## MyApp
-
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TaskItem.self)
    }
}
De maneira bem simples, o myApp contempla a raiz e a view principal do app, sem problemas aqui, entao nao tem muito o que contar aqui, apenas que o container do swiftData foi criado e implementado a entidade necesaria (TaskItem).

## Models
-
A primeira model que temos e do tipo de friccao, que comeca com varios tipos, desde planejamento, desconforto, contagem, memoria, e cada um deles tem um label respectivo e um simbolo representante.
```
@Generable
enum FrictionType: String, CaseIterable, Codable, Sendable {
    case counting
    case memory
    case constraint
    case focus
    case discomfort
    case planning

    var label: String {
        switch self {
        case .counting: "Counting"
        case .memory: "Memory"
        case .constraint: "Constraint"
        case .focus: "Focus"
        case .discomfort: "Discomfort"
        case .planning: "Planning"
        }
    }

    var symbolName: String {
        switch self {
        case .counting: "number"
        case .memory: "brain.head.profile"
        case .constraint: "hand.raised"
        case .focus: "scope"
        case .discomfort: "flame"
        case .planning: "map"
        }
    }
}
```

Com isso, temos outra entidade, a savedChallenge, que representa um desafio de friccao
```
/// A friction challenge the person accepted and saved to a task.
struct SavedChallenge: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var instruction: String
    var type: FrictionType
    var difficulty: Int
    var rationale: String

    init(id: UUID = UUID(), title: String, instruction: String, type: FrictionType, difficulty: Int, rationale: String) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.type = type
        self.difficulty = difficulty
        self.rationale = rationale
    }
}
```

Essa entidade possui todos os valores necessarios para a geracao de um desafio, e ja usa o FrictionType para definir o tipo do desafio.

Depois temos o TaskItem, que representa uma tarefa que o usuario criou para gerar as tarefas.
```
/// A task the person wants to add mental friction to, like "Swimming".
@Model
final class TaskItem {
    var title: String
    var notes: String
    var createdAt: Date
    var savedChallenges: [SavedChallenge]

    init(title: String, notes: String = "") {
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.savedChallenges = []
    }
}
```

nao tem muito segredo aqui, uma tarefa tem um array de desafios salvos, o mais diferente aqui e isso e o @Generable que serve para todas as entidades que podem ser preenchidas por um modelo on-device, que nosso caso e o foudations e vamos entender isso daqui para frente.

## FrictionEngine
-
A frictionEngine e o arquivo em que a logica principal do app roda, explorando os principais pontos do foundations, entao vamos comecar com o topo e ir passando para baixo:
Primeiro temos o FrictionChallenge, que e um desafio gerado pelo foundations (por isso @generable), que possui a mesma estrutura do savedChallenge
E temos o plano, que possui uma analise e um array de FrictionChallenge.
O ponto mais legal aqui, e que o @Guide(description:) e usado, que serve para guiar o modelo na geracao de cada variavel, o que ajuda muito no material que vai ser criado.
``` 
/// One mental-friction challenge suggested for a task.
@Generable
struct FrictionChallenge: Sendable {
    @Guide(description: "Short challenge title, up to 6 words")
    var title: String

    @Guide(description: "Concrete, executable instruction to follow during the task, no extra equipment")
    var instruction: String

    @Guide(description: "Category of the mental friction type the challenge exercises")
    var type: FrictionType

    @Guide(description: "Difficulty of the mental friction, from 1 (light) to 5 (extreme)", .range(1...5))
    var difficulty: Int

    @Guide(description: "One-sentence explanation of why this challenge increases mental friction")
    var rationale: String
}

/// The full plan the model proposes for a task.
@Generable
struct FrictionPlan: Sendable {
    @Guide(description: "Brief analysis, in 1-2 sentences, of where the task's main mental effort lies")
    var analysis: String

    @Guide(description: "Mental friction challenges for the task, varying the types between them", .count(5))
    var challenges: [FrictionChallenge]
}
```
Essas duas entidades servem para quando eu gerar as atividades dentro de uma tarefa, gerar uma analise do por que as tarefas sao de friccao e cada tarefa seguir nossa view certinha.
Depois temos o FrictionContext e o ExistingChallengesTool que trabalham em conjunto. 
como a propria doc da apple fala, uma Tool e uma ferramenta que um modelo pode chamar para pegar informacao durante a execucao ou performar outros efeitos.
```
/// Read-only context handed to tools so they don't need to touch the SwiftData model directly.
struct FrictionContext: Sendable {
    var taskTitle: String
    var taskNotes: String
    var existingChallengeTitles: [String]
}

/// Lets the model check which challenges were already accepted for this task, so it can avoid repeating itself.
struct ExistingChallengesTool: Tool {
    let name = "existingChallenges"
    let description = "Returns the titles of the mental friction challenges already accepted for this task, to avoid repetition."
    let context: FrictionContext

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard !context.existingChallengeTitles.isEmpty else {
            return "No challenge has been accepted for this task yet."
        }
        return context.existingChallengeTitles.joined(separator: "; ")
    }
}

```

Uma tool e chamada pelo foudations baseando-se no que foi recebido a ele e algo que devemos saber e que toda tool possui uma func call e geralmente um arguments, que pode ser um valor de quantidade ou outro valor necessario, mas mesmo que compile, sempre coloque arguments, pois sem, o modelo pode nao funcionar

```
private let frictionInstructions = """
You are a coach who designs "mental friction" for physical or routine tasks.

Mental friction is a deliberate cognitive obstacle — counting, memorization, sensory restriction, attentional focus, controlled discomfort, or planning — that the person adds to the task to exercise the brain, not the body.

Rules:
- Physical safety always comes first: never propose anything that increases risk of injury, drowning, accident, or dangerous distraction.
- Be specific to the context of the received task; generic challenges don't work.
- Before proposing, use the "existingChallenges" tool to avoid repeating challenges already accepted.
- Vary the types (counting, memory, restriction, focus, discomfort, planning) between the challenges of a single plan.
- Each instruction must be executable in a few words, with no extra equipment.

Example for the task "5km run":
- Counting: "Count your steps in blocks of 7 until you lose count, and restart from zero without getting frustrated."
- Memory: "Memorize 5 random words before starting and recite them in reverse order during the last kilometer."
"""
```

Depois disso temos a friction engine, que prepara uma sessao do foundations, responsavel por transformar uma tarefa em um plano de desafios de friccao mental.
Inicialmente ele conta com 3 variaveis, um state, que segue alguns valores para definir loading, streaming, finished, failed, assim mantemos varias flags relacionadas aos estados de processamento do modelo.
Depois temos a session, que e a de um modelo de linguagem, comeca nulo e ele e preparado depois.
por fim, a availability, que pega a disponibilidade do modelo.

```
/// Drives a Foundation Models session that turns a task into a plan of mental-friction challenges.
@Observable
final class FrictionEngine {
    enum State {
        case idle
        case loading
        case streaming(FrictionPlan.PartiallyGenerated)
        case finished(FrictionPlan)
        case failed(String)
    }

    private(set) var state: State = .idle

    private var session: LanguageModelSession?

    /// Whether the on-device model is ready to use right now.
    var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }
    
```

Depois, temos algumas funçoes publicas, prewarm, generate e requesHarder, com seus respecitvos helpers (funçoes privadas).
- prewarm: responavel por preparar a sessao do modelo, assim a primeira requisicao parece mais rapida, cria uma sessao com o helper makeSession e prepara um prompt base, mas o prewarm usado internamente serve para preparar o modelo mais rapido, devendo ser usado somente quando temos a certeza que nosso usuario vai usar uma requisicao do modelo logo apos.
- generate: prepara uma tarefa e uma criatividade, monta um prompt basico e prepara as options que pega essa criatividade definida e adiciona na temperature (que representa a criatividade do modelo)
- Depois usa o stream(), uma funçao privada que prepara o prompt, a entidade a ser gerada e as options necessarias.
```
    /// Loads the model into memory ahead of time, so the first real request feels faster.
    func prewarm(for task: TaskItem) {
        guard availability == .available else { return }
        let activeSession = makeSession(context: makeContext(for: task))
        session = activeSession
        activeSession.prewarm(promptPrefix: Prompt("Task: \(task.title)."))
    }

    func generate(for task: TaskItem, creativity: Double) async {
        state = .loading

//        // TEMPORARY DIAGNOSTIC round 2: @Generable structured generation, but NO tools —
//        // isolates whether it's specifically tool calling that fails.
//        let activeSession = LanguageModelSession(instructions: frictionInstructions)
//        session = activeSession

        let prompt = """
        Task: \(task.title)
        Notes: \(task.notes.isEmpty ? "none" : task.notes)
        Generate the mental friction plan for this task.
        """

        var options = GenerationOptions()
        options.temperature = creativity

        if let currentSession = session {
            await stream(currentSession.streamResponse(to: prompt, generating: FrictionPlan.self, options: options))
        }
    }
```
Precisamos pausar para mostrar o ponto do stream, uma funçao privada, pois ela tem algo que eu acredito que seja bem novo:
```
private func stream(_ responseStream: sending LanguageModelSession.ResponseStream<FrictionPlan>) async {
        do {
            for try await snapshot in responseStream {
                state = .streaming(snapshot.content)
            }
            let response = try await responseStream.collect()
            state = .finished(response.content)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }
```
Como podemos ver, ela recebe um responseStream que e o resultado que o modelo vai devolvendo aos poucos quando voce pede uma geraçao estruturada, e pegamos para cada um desses conteudos gerados, atualizamos o estado atual para .streaming, para assim podemos montar a UI sendo construida, dando a ideia do plano sendo progressivamente construido.
Aprendi escrevendo isso tambem o que e uma stream, que e basicamente uma sequencia de valores que vao chegando aos poucos ao longo do tempo, por isso podemos fazer esse stream que estamos fazendo agora.
Ao terminar todo o loop (a resposta ser toda construida), salvamos a resposta com .collect() e colocamos o estado em finished.
Pegamos esse parametro pois e o que usamos na session na funcao de generate, com .streamReponse()
e uma forma bem legal de tratar dados que veem progressivamente, assim podemos nos manter constantemente mostrando a construçao do plano para o usuario.
Voltando para as funçoes publicas, temos so mais uma, a requestHarder que refaz a stream com a mesma sessao mas agora passando outro prompt.
```
/// Reuses the same session, asking the model to escalate the difficulty of the current plan.
    func requestHarder() async {
        guard let activeSession = session else { return }
        state = .loading
        await stream(
            activeSession.streamResponse(
                to: "Redo the plan keeping the same format, but make each challenge noticeably harder.",
                generating: FrictionPlan.self
            )
        )
    }
    
```
Agora podemos falar sobre algo legal do prewarm tambem, que ele usa outras 2 funçoes privadas, a makeSession com makeContext dentro, elas servem para preparar o modelo atual, e o contexto para a tool que o modelo vai usar.
```
private func makeContext(for task: TaskItem) -> FrictionContext {
        FrictionContext(
            taskTitle: task.title,
            taskNotes: task.notes,
            existingChallengeTitles: task.savedChallenges.map(\.title)
        )
    }

    private func makeSession(context: FrictionContext) -> LanguageModelSession {
        LanguageModelSession(
            model: .default,
            tools: [ExistingChallengesTool(context: context)],
            instructions: frictionInstructions
        )
    }
```
como voce pode ver, o make context prepara o objeto frictionContext para  com o titulo e notas, junto com os desafios ja salvos para a tool conseguir estar pronta quando necessaria.
A session e a sessao do modelo, define um modelo especifico, as tools, e ate as instruçoes.

## ContentView
-
A contentView contempla algumas variaveis:
@Environment(\.modelContext) private var modelContext
@Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
@State private var isAddingTask = false
@State private var newTaskTitle = ""
@State private var newTaskNotes = ""

- Environment e o contexto do swiftData
- Query e a nossa busca no campo do swiftData por todos os TaskItems
- isAddingTask e nossa flag de disparo para adicionar nova tarefa
- newTaskTitle e newTaskNotes sao os dados iniciais para geracao de uma nova tarefa.

A view por si so e uma navigationStack com uma lista, sem muito segredo. Algo legal e o .onDelete que temos que permite o swipe nativo para deletar um elemento, e com isso ele performa um delete tasks que e uma func da view que so pega o contexto e deleta o elemento dentro de tasks.
A view conta com diversos modificadores, tem a navigationTitle que e o titulo do app, a destination que muda a tela para a tela de detalhes e uma toolbar que e onde temos um item de button que dispara nosso gatilho de criar nova task.
Algo que temos tambem e o overlay que consta uma view que cobre tudo quando as tarefas estao vazias. que'e a ContentUnavailableView, algo bem legal que podemos gerar pronto do swift, que e uma view simples usada quando nao podemos mostrar uma certa view (lista vazia aqui no caso).
Depois temos uma sheet, que e a de adicionar tarefa, usando um componente pronto chamado Form (nao sabia) que basicamente tem dois textFields que preenchem as duas variaveis la em cima, e ao aceitar (create), rodamos o addTask() que gera um novo item e adiciona no banco.  
Algo legal que podemos ver e o .presentationDetents (nao sabia) que e para colocarmos no conteudo de uma sheet e definimos assim o tamanho dela.
caso o usuario cancele, o resetForm() roda, e com isso os dados voltam a ficar strings com "" somente.

## TaskDetailView
-
Essa tela aparece quando clicamos em um elemento da lista, e temos algo mais complexo aqui.
Primeiro temos uma struct da view, que serve para mostrar um desafio, tendo alguns valores como:
```private struct ChallengeDisplay {
    var title: String?
    var instruction: String?
    var type: FrictionType?
    var difficulty: Int?
    var rationale: String?

    init(_ challenge: FrictionChallenge) {
        title = challenge.title
        instruction = challenge.instruction
        type = challenge.type
        difficulty = challenge.difficulty
        rationale = challenge.rationale
    }

    init(_ partial: FrictionChallenge.PartiallyGenerated) {
        title = partial.title
        instruction = partial.instruction
        type = partial.type
        difficulty = partial.difficulty
        rationale = partial.rationale
    }
}
```
Podemos ver aqui que temos uma sobrecarga de construtores, onde podemos ter uma construcao parcial ou totalmente construida, e para isso precisamos entender outro elemento:


