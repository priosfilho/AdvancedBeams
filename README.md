# 🎵 Advanced Beams - MuseScore 4 Plugin

**Version:** 2.5  
**Compatibility:** MuseScore Studio 4.x  
**Category:** Notes & Rests (notes-rests)

The **Advanced Beams** plugin provides extended control over the height, slope, growth (grow), and state preservation of beams and stems in MuseScore 4. It addresses specific workflow limitations in the native interface, such as independently adjusting up/down beams, applying horizontal alignment reliably, and restoring manual edits that are reset after time signature changes.

---

## 📋 Main Features

The plugin is divided into 5 main sections (A to E) plus a control footer:

### Section A — Beam Height
Adjusts the vertical position of the beams.
*   **Delta:** Relative adjustment using ▲▼ buttons. Applies to all beams or targeted ones only (up/down). *Note: Up beams (up=true) automatically receive the inverse sign for correct visual movement.*
*   **Absolute:** Sets an exact position. The plugin zeroes the internal position (`beamPos`) and applies the absolute value to `offset.y`, preventing value accumulation. Separate values for "Up" and "Down" beams. You can **Save Abs Defaults** for future sessions.
*   **Force horizontal:** Forces beams to be flat, ensuring the manual state is registered correctly by the software.
*   **Restore slope:** Restores the automatic slope calculation.
*   **Reset Height / Factory Reset:** Restores height to the plugin session baseline or to the software defaults.

### Section B — Grow Beams
Controls the lateral expansion/retraction of beams (`growLeft` and `growRight` properties).
*   Independent adjustment for Left, Right, or both (L+R).
*   **Joint beams:** Sets growth to `0.0` (beams joined/no extension).
*   **Factory Reset Grow:** Returns to `1.0` (default).
*   **Reset Grow:** Returns to the session baseline.

### Section C — Select Beams
Filters the current selection to isolate only beams pointing up (`up=true`) or down (`up=false`). Useful for applying changes to only one direction without affecting the other.

### Section D — Isolated Stems
Relative adjustment (percentage delta) for stems that do **not** have beams.
*   Fine control with ▲▼ buttons.
*   Option to include or ignore grace notes attached to selected chords.

### Section E — Restore AdvancedBeams
Saves and restores the exact state of the beams. Useful for preserving beam states after time signature changes, which can sometimes reset manual edits.
*   **Save snap:** Saves a restore point (snapshot) for the current selection.
*   **Restore snap:** Restores the saved snapshot after an alteration that resets the beams.
*   **Load file:** Loads snapshots from external files.
*   **Clear snap:** Clears the snapshot from memory.

### Footer
*   **Diagnose:** Displays information about selected elements in the status log.
*   **Reset All:** Restores all properties from Sections A and B to the current session baseline.
*   **Close:** Closes the plugin.

---

## ⚙️ Installation

1. Copy the `AdvancedBeams.qml` file into your MuseScore plugins folder.
2. In MuseScore 4, go to **Plugins** → **Plugin Manager...**.
3. Find **"Advanced Beams"** in the list and check the box to enable it.
4. The plugin will be available via the menu: **Plugins** → **Advanced Beams**.

---

## 💡 Usage Tips

*   **Before using:** Always select a range in the score or specific notes/chords. The plugin acts on the selection.
*   **Absolute Edits:** When using "Apply ↑" or "Apply ↓", the plugin runs a "priming" routine on the beams to ensure the software registers the manual adjustment correctly.
*   **Time Signature Changes:** If you need to change the time signature of a passage that has already had its beams adjusted, use **Section E** to save a snapshot *before* the change, and restore it *after*.
*   **Defaults File:** Clicking "Save abs defaults" creates a file named `AdvancedBeams_abs_defaults.txt` in the plugin folder or Documents folder. This keeps your preferred absolute height values saved across different sessions.

---

## 🧠 Acknowledgments & Authorship

This script was developed within the research group CM.ÊPA! — Criação Musical, Experimentação e Pesquisa Artística (UFSM/CNPq), by Dr. Paulo Rios Filho.

The program was written in QML/JavaScript, with the support of generative artificial intelligence agents in the code elaboration, revision, debugging, and refinement process. Claude Sonnet 4.6 (Anthropic) and GPT-5.5 Thinking (OpenAI/ChatGPT) were used as programming assistants. The conception of the script, the definition of its functionalities, the orientation of the solutions, the practical testing, the critical review, and the final implementation decisions were conducted by the human agent responsible for the project.

**CM.ÊPA! — Criação Musical, Experimentação e Pesquisa Artística:**  
🔗 [https://www.ufsm.br/grupos/cmepa](https://www.ufsm.br/grupos/cmepa)

---
---

# 🎵 Advanced Beams - Plugin para MuseScore 4

**Versão:** 2.5  
**Compatibilidade:** MuseScore Studio 4.x  
**Categoria:** Notas e Pausas (notes-rests)

O plugin **Advanced Beams** oferece um controle estendido sobre a altura, inclinação, crescimento (grow) e o estado de preservação dos colchetes (beams) e hastes (stems) no MuseScore 4. Ele atende a limitações específicas do fluxo de trabalho na interface nativa, como ajustar colchetes para cima e para baixo de forma independente, aplicar o alinhamento horizontal de forma confiável e restaurar edições manuais que são redefinidas após mudanças de fórmula de compasso.

---

## 📋 Funcionalidades Principais

O plugin é dividido em 5 seções principais (A a E) mais um rodapé de controle:

### Seção A — Altura do Colchete (Beam Height)
Ajusta a posição vertical dos colchetes.
*   **Delta:** Ajuste relativo usando os botões ▲▼. Aplica-se a todos os colchetes ou apenas aos direcionados (up/down). *Nota: Colchetes para cima (up=true) recebem o sinal inverso automaticamente para movimento visual correto.*
*   **Absoluto:** Define uma posição exata. O plugin zera a posição interna (`beamPos`) e aplica o valor absoluto no `offset.y`, evitando acúmulo de valores. Valores separados para colchetes "Up" e "Down". É possível **Salvar Padrões Absolutos** para uso futuro em outras sessões.
*   **Force horizontal:** Força o colchete a ficar reto, garantindo que o estado manual seja registrado corretamente pelo software.
*   **Restore slope:** Restaura o cálculo de inclinação automática.
*   **Reset Height / Factory Reset:** Restaura a altura para o início da sessão do plugin ou para os padrões do software.

### Seção B — Crescimento do Colchete (Grow Beams)
Controla a expansão/recuo lateral dos colchetes (propriedades `growLeft` e `growRight`).
*   Ajuste independente para Esquerda (Left), Direita (Right) ou ambos (L+R).
*   **Joint beams:** Define o crescimento para `0.0` (colchetes colados/sem extensão).
*   **Factory Reset Grow:** Retorna para `1.0` (padrão).
*   **Reset Grow:** Retorna para a linha de base da sessão.

### Seção C — Selecionar Colchetes (Select Beams)
Filtra a seleção atual para isolar apenas os colchetes apontando para cima (`up=true`) ou para baixo (`up=false`). Útil para aplicar alterações em apenas uma direção sem afetar a outra.

### Seção D — Hastes Isoladas (Isolated Stems)
Ajuste relativo (delta percentual) para hastes que **não** possuem colchetes.
*   Controle fino com botões ▲▼.
*   Opção para incluir ou ignorar notas de grace (apogiaturas) anexadas aos acordes selecionados.

### Seção E — Restaurar AdvancedBeams (Restore/Snapshot)
Salva e restaura o estado exato dos colchetes. Útil para preservar o estado dos colchetes após mudanças de fórmula de compasso, que podem redefinir as edições manuais.
*   **Save snap:** Salva um "ponto de restauração" (snapshot) para a seleção atual.
*   **Restore snap:** Restaura o snapshot salvo após alguma alteração que redefina os colchetes.
*   **Load file:** Carrega snapshots a partir de arquivos externos.
*   **Clear snap:** Limpa o snapshot da memória.

### Rodapé
*   **Diagnose:** Exibe no log/status informações sobre os elementos selecionados.
*   **Reset All:** Restaura todas as propriedades das Seções A e B para a linha de base da sessão atual.
*   **Close:** Fecha o plugin de forma segura.

---

## ⚙️ Instalação

1. Copie o arquivo `AdvancedBeams.qml` para a sua pasta de plugins do MuseScore.
2. No MuseScore 4, vá em **Plugins** → **Gerenciador de Plugins...**.
3. Encontre **"Advanced Beams"** na lista e marque a caixa de seleção para habilitá-lo.
4. O plugin estará disponível no menu: **Plugins** → **Advanced Beams**.

---

## 💡 Dicas de Uso

*   **Antes de usar:** Sempre selecione um trecho da partitura (range selection) ou selecione notas/acordes específicos. O plugin age sobre a seleção.
*   **Edições Absolutas:** Ao usar "Apply ↑" ou "Apply ↓", o plugin executa uma rotina de "preparação" (priming) nos colchetes para garantir que o software registre o ajuste manual corretamente.
*   **Mudança de Compasso:** Se você precisar alterar a fórmula de compasso de um trecho que já teve os colchetes ajustados, use a **Seção E** para salvar um snapshot *antes* da mudança, e restaure *depois*.
*   **Arquivo de Padrões:** Ao clicar em "Save abs defaults", o plugin cria um arquivo chamado `AdvancedBeams_abs_defaults.txt` na pasta do plugin ou de Documentos. Isso mantém seus valores preferidos de altura absoluta salvos entre diferentes sessões.

---

## 🧠 Créditos e Autoria

Este script foi desenvolvido no âmbito do grupo de pesquisa CM.ÊPA! — Criação Musical, Experimentação e Pesquisa Artística (UFSM/CNPq), pelo Dr. Paulo Rios Filho.

O programa foi escrito em linguagem QML/JavaScript, com apoio de agentes de inteligência artificial generativa no processo de elaboração, revisão, depuração e refinamento do código. Foram utilizados Claude Sonnet 4.6, da Anthropic, e GPT-5.5 Thinking, da OpenAI/ChatGPT, como assistentes de programação. A concepção do script, a definição de suas funcionalidades, a orientação das soluções, os testes práticos, a revisão crítica e as decisões finais de implementação foram conduzidos pelo agente humano responsável pelo projeto.

**Grupo de pesquisa CM.ÊPA! — Criação Musical, Experimentação e Pesquisa Artística:**  
🔗 [https://www.ufsm.br/grupos/cmepa](https://www.ufsm.br/grupos/cmepa)