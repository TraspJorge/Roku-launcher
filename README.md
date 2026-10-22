# Meu Menu (Roku launcher)

Tela inicial personalizada, no estilo Apple TV, para **Roku TV** (testado numa AOC 32" com Roku OS 15.3.4).
É instalada como app de desenvolvedor (sideload) e abre automaticamente quando a TV liga.

## Recursos
- Destaque com prévia do app, fundo com a cor do app em foco, ícones arredondados com sombra e brilho
- Abertura animada: os quadradinhos da tela de abertura voam até a grade e viram os ícones
- Tecla ✱: mover apps (ordem personalizada), remover do menu, restaurar apps removidos
- Mascotes: olhos do Gengar no fundo, Pikachu correndo e Rimuru slime pulando pela borda de baixo
- Lista de apps atualizada automaticamente quando um app é instalado ou removido na TV

## Como funciona
A Roku não deixa um app listar nem abrir outros pela rede local (ECP responde 403 de dentro do app),
então um serviço no PC (`tools/servico_tv.py`) faz a ponte:
- lê os apps e ícones da TV e grava em `app/source/apps.json` / `app/images/apps/`
- reinstala o app quando a lista muda (só com o Meu Menu na tela ou ao ligar a TV)
- abre o Meu Menu quando a TV liga na tela inicial

Os apps são abertos de dentro do menu com `roAppManager.LaunchApp`.

## Configuração
1. Ative o Modo Desenvolvedor na TV (Home ×3, Cima ×2, Direita, Esquerda, Direita, Esquerda, Direita)
2. Em Configurações → Sistema → Configurações avançadas → Controle por apps móveis → Acesso à rede: **Padrão**
3. Copie `tools/config.exemplo.json` para `tools/config.json` com o IP da TV e a senha do Modo Desenvolvedor
4. Instale o serviço: veja `tools/roku-meu-menu.service`

## Estrutura
| Pasta/arquivo | Conteúdo |
|---|---|
| `app/` | Código do app Roku (BrightScript/SceneGraph) |
| `tools/servico_tv.py` | Serviço do PC (abrir ao ligar, atualizar a lista, instalar) |
| `tools/gerar_*.py` | Geram ícone, imagens da interface e mascotes (requer Pillow para os mascotes) |

## Créditos
Animação do Pikachu: GIF de [gifdb.com](https://gifdb.com/gif/pokemon-pikachu-running-fdcgna00aeogxcjz.html) (fundo removido).
Pokémon e Rimuru pertencem aos seus respectivos donos; uso pessoal.
