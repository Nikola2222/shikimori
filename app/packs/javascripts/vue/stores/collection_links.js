import groupBy from 'lodash/groupBy';
import last from 'lodash/last';
import sortBy from 'lodash/sortBy';
import uniq from 'lodash/uniq';

let uniqId = 987654321;
const newId = () => uniqId += 1;

const hasDuplicate = (links, link) =>
  links.some(v =>
    (v !== link) &&
      (v.linked_id === link.linked_id) &&
      (v.group === link.group)
  );

const noLinksToFill = (links, group) =>
  !links.some(v => (v.group === group) && !v.linked_id);

export default {
  state: {
    collection: {}
  },

  getters: {
    collection(store) { return store.collection; },
    links(store) { return store.collection.links; },
    groups(store) { return store.collection.links.map(v => v.group) |> uniq(?); },
    groupedLinks(store) { return store.collection.links |> groupBy(?, v => v.group); }
  },

  actions: {
    fillLink({ commit, state }, { link, changes }) {
      commit('FILL_LINK', { link, changes });

      if (hasDuplicate(state.collection.links, link)) {
        commit('REMOVE_LINK', link);
      }

      if (noLinksToFill(state.collection.links, link.group)) {
        commit('ADD_LINK', { group: link.group });
      }
    },

    addLink({ commit }, data) { commit('ADD_LINK', data); },
    removeLink({ commit }, data) { commit('REMOVE_LINK', data); },
    moveLink({ commit }, data) { commit('MOVE_LINK', data); },
    moveGroupLeft({ commit, getters }, groupName) {
      const index = getters.groups.indexOf(groupName);

      commit('SWAP_GROUPS', {
        groupLeft: getters.groups[index - 1],
        groupRight: groupName
      });
    },
    moveGroupRight({ commit, getters }, groupName) {
      const index = getters.groups.indexOf(groupName);

      commit('SWAP_GROUPS', {
        groupLeft: groupName,
        groupRight: getters.groups[index + 1]
      });
    },
    renameGroup({ commit }, data) { commit('RENAME_GROUP', data); },
    refill({ commit }, data) { commit('REFILL', data); }
  },

  mutations: {
    ADD_LINK(state, linkData) {
      const link = {
        group: null,
        linked_id: null,
        name: null,
        text: '',
        url: null,
        key: newId(),
        ...linkData
      };

      if (link.linked_id && hasDuplicate(state.collection.links, link)) { return; }

      const lastInGroup = state.collection.links
        .filter(v => v.group === link.group)
        |> last(?);
      const index = state.collection.links.indexOf(lastInGroup);

      if (index !== -1) {
        state.collection.links.splice(index + 1, 0, link);
      } else {
        state.collection.links.push(link);
      }
    },

    REMOVE_LINK(state, link) {
      state.collection.links.splice(
        state.collection.links.indexOf(link),
        1
      );
    },

    MOVE_LINK(state, { fromIndex, toIndex, groupIndex }) {
      const { group } = state.collection.links[groupIndex];
      const fromElement = state.collection.links.splice(fromIndex, 1)[0];

      if (fromElement.group !== group) { fromElement.group = group; }

      if (!hasDuplicate(state.collection.links, fromElement)) {
        state.collection.links.splice(toIndex, 0, fromElement);
      }
    },

    RENAME_GROUP(state, { fromName, toName }) {
      state.collection.links.forEach(link => {
        if (link.group === fromName) {
          link.group = toName;
        }
      });
    },

    SWAP_GROUPS({ collection }, { groupLeft, groupRight }) {
      const groups = collection.links.map(v => v.group) |> uniq(?);
      const links = collection.links |> sortBy(?, v => groups.indexOf(v.group));

      const leftIndex = links.findIndex(v => v.group === groupLeft);
      const leftItems = links.filter(v => v.group === groupLeft);

      const rightIndex = links.findIndex(v => v.group === groupRight);
      const rightItems = links.filter(v => v.group === groupRight);

      collection.links = [
        ...links.slice(0, leftIndex),
        ...rightItems,
        ...leftItems,
        ...links.slice(rightIndex + rightItems.length, collection.links.length)
      ];
    },

    FILL_LINK(state, { link, changes }) {
      Object
        .entries(changes)
        .forEach(([key, value]) => link[key] = value);
    },

    REFILL(state, data) {
      state.collection.links = data;
    }
  },

  modules: {}
};
