import filter from 'lodash/filter';
import isEmpty from 'lodash/isEmpty';
import uniqBy from 'lodash/uniqBy';

let uniqId = 987654321;
const newId = () => uniqId += 1;

// store for simple collection of items
export default {
  state: {
    collection: []
  },

  actions: {
    replace({ commit }, collection) { commit('REPLACE', collection); },
    add({ commit }, item) { commit('ADD', item); },
    remove({ commit }, key) { commit('REMOVE', key); },
    update({ commit }, item) { commit('UPDATE', item); },
    cleanup({ commit }) { commit('CLEANUP'); }
  },

  mutations: {
    REPLACE(state, collection) {
      state.collection = collection;
    },

    ADD(state, item) {
      state.collection.push({ ...item, key: newId() });
    },

    REMOVE(state, key) {
      state.collection.splice(state.collection.findIndex(v => v.key === key), 1);
    },

    UPDATE(state, item) {
      const index = state.collection.findIndex(v => v.key === item.key);

      state.collection[index] = item;
    },

    CLEANUP(state) {
      state.collection.forEach(item => {
        item.value = item.value.trim();
      });

      state.collection = state.collection
        |> filter(?, 'value')
        |> uniqBy(?, 'value');
    }
  },

  getters: {
    collection(store) { return store.collection; },
    isCollectionEmpty(store) {
      return store.collection.every(item =>
        isEmpty(item.url) && isEmpty(item.value) && isEmpty(item.name)
      );
    }
  },

  modules: {}
};
